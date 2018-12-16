import gc
import glob
import operator
import os

import numpy as np
import time
import datetime

from fourq_hardware import fourq_scalar_mult
from fourq_software import scalar_recoding, scalar_decomposition
from lecroy import lecroy_interface
from lecroy import trace_set_coding
from sakura_g import ftdi_interface
from utils import files

lecroy_if = None  # type: lecroy_interface.Lecroy
trace_set_encoder = trace_set_coding.TraceSetCoding()

nr_of_additional_traces = None


def online_template_attack(base_point, secret_scalar, use_decomposed_scalar=True, average_template_signals=False,
                           max_nr_of_iterations=64, enable_output=True, recapture_target_trace=False, plot_intermediate_templates=False):
    """
    This function does the following:
    - load the base point onto the FourQ implementation
    - capture the target trace
    - [determine the offsets of the doubling operations]
    - Attack the key bits:
        * Generate the corresponding templates:
            * Obtain the multi_scalar that belongs to the wanted recoded matrix
            * Obtain the scalar that decomposes into the multi-scalar in the previous step
            * Load this scalar in the FourQ implementation
        * Correlate the template (at the correct doubling operation using the offsets) with the target trace (again
        at the correct doubling operation using the offsets)
        * Choose the values for the digit-column and sign that give the highest correlation and repeat for every
        iteration in the scalar multiplication of FourQ.
    :param base_point:
    :return:
    """
    # Decompose scalar [if necessary] and calculate recoded matrix for verifying column guesses
    if not use_decomposed_scalar:
        decomposed_secret_scalar = scalar_decomposition.decompose_scalar(secret_scalar)
    else:
        decomposed_secret_scalar = secret_scalar
    decomposed_secret_scalar = np.asarray(decomposed_secret_scalar, dtype=np.uint64)
    recoded_secret_scalar_matrix = scalar_recoding.recode_multi_scalar_general_unoptimized(decomposed_secret_scalar,
                                                                                           2 ** 256)

    # Connect to Sakura
    sakura = ftdi_interface.SaseboGii()

    # lecroy_if.save_panel_to_file("lecroy_ota_config.dat")
    # lecroy_if.load_lecroy_cfg()

    # Initialize ROM constants
    fourq_scalar_mult.fourq_initialize_rom(sakura)

    # Load base point
    x0, x1 = base_point[0]
    y0, y1 = base_point[1]
    fourq_scalar_mult.fourq_write_base_point(sakura, x0, x1, y0, y1)

    # Load secret scalar
    load_scalar(sakura, secret_scalar, use_decomposed_scalar)
    # capture_trace(sakura)

    # Capture target trace [if needed]
    if recapture_target_trace:
        target_trace_interpreted = capture_trace(sakura, save_to_file=recapture_target_trace, file_name="target_trace")
        save_target_trace(target_trace_interpreted)
    else:
        target_trace_interpreted = load_target_trace()

    # Determine offsets
    oper_trigger_trace = capture_trace(sakura, channel="C2", save_to_file=False,
                                       file_name="oper_trigger_trace")

    # The offsets containing offsets for both the doubling and addition operations.
    offsets = determine_offsets_static(oper_trigger_trace, nth_diff=1)
    # The order of the offsets is: [DBL, ADD, DBL, ..., DBL, ADD]
    # Even elements contain the DBL offsets, odd elements the ADD offsets
    # There are 64 DBL and 64 ADD operations, giving 128 offsets in total (if the whole main loop was captured)

    rank_per_iter = []

    attacked_digit_columns = None
    # We are now going to attack the digit columns iteratively (starting from digit column 64)
    for iteration in reversed(range(64)):
        corr_results = attack_digit_column(sakura, iteration, offsets, target_trace_interpreted, attacked_digit_columns,
                                           use_decomposed_scalar=use_decomposed_scalar,
                                           average_template_signals=average_template_signals,
                                           plot_intermediate_templates=plot_intermediate_templates,
                                           use_points_of_interest=False,
                                           use_fft=False)
        # Determine which (template digit column, correlation value) had the highest correlation value
        template_digit_column, max_corr_coeff = max(corr_results, key=operator.itemgetter(1))

        if enable_output:
            print("Iteration: {}. Attacking d{}".format(iteration, iteration + 1))
            print("Expected digit column: \t{}".format(recoded_secret_scalar_matrix[:, 63 - iteration]))
            print("Digit column guess: \t{}".format(template_digit_column[:, 0]))
            print("Correlation results (from lowest to highest:")
        for idx, (tmpl_digit_col, corr_coeff) in enumerate(sorted(corr_results, key=operator.itemgetter(1))):
            equals_correct_template = np.array_equal(tmpl_digit_col[:, 0],
                                                     recoded_secret_scalar_matrix[:, 63 - iteration])
            if equals_correct_template:
                rank = len(corr_results) - idx
                rank_per_iter.append(rank)
            if enable_output:
                print("{}: \t {}{} ".format(tmpl_digit_col[:, 0], corr_coeff, "*" if equals_correct_template else ""))
        if enable_output:
            print("Rank of expected: \t {} from {} templates in total".format(rank, len(corr_results)))

        # TODO for testing, we always assume we have guesses the current digit column correctly
        if attacked_digit_columns is not None:
            attacked_digit_columns = np.concatenate(
                (attacked_digit_columns, recoded_secret_scalar_matrix[:, [63 - iteration]]), axis=1)
        else:
            attacked_digit_columns = recoded_secret_scalar_matrix[:, [63 - iteration]]

        # attacked_digit_columns = np.concatenate((attacked_digit_columns, template_digit_column), axis=1) \
        #     if attacked_digit_columns is not None else template_digit_column

        if 63 - max_nr_of_iterations == iteration:
            break
        del corr_results
        gc.collect()

    if enable_output:
        print("Ranks per iteration (starting from i=63: {}".format(rank_per_iter))
    # return attacked_digit_columns
    return rank_per_iter


def obtain_template_traces(sakura, is_first_iteration, attacked_digit_columns, use_decomposed_scalar=True,
                           average_template_signals=False):
    """
    Obtain the template traces given the previously attacked digit columns
    :param average_template_signals:
    :param use_decomposed_scalar:
    :param sakura: The interface with the Sakura-G FPGA
    :param is_first_iteration: Whether this is the first iteration of FourQ
    :param attacked_digit_columns: The previously attacked digit columns
    :return: A list of template traces
    """
    sign_vals = [1] if is_first_iteration else [1, -1]

    template_traces = []
    template_digit_columns = []

    for s_i in sign_vals:
        for d_i in range(8):
            # Generate template with expected digit column(s)
            template_digit_column = scalar_recoding.generate_digit_column_for_value(d_i, s_i)
            digit_columns_guess = template_digit_column

            # If it is not the first iteration, we append our previously attacked digit columns with our current guess
            if not is_first_iteration:
                digit_columns_guess = np.concatenate((attacked_digit_columns, template_digit_column), axis=1)

            # Determine corresponding multi-scalar: inverse the decomposition or take the decomposed scalar
            if use_decomposed_scalar:
                recoded_matrix, is_valid_template = scalar_recoding.get_valid_recoded_matrix(
                    digit_columns_guess, 65)
                scalar = scalar_recoding.matrix_to_scalars(recoded_matrix) if is_valid_template else None

            else:
                # TODO inverse decomposition is a work in progress!
                scalar = None
                is_valid_template = False

            # If the current configuration of values cannot produce a valid set of scalars, we continue with the next
            # iteration
            if not is_valid_template:
                continue

            # Load scalar
            load_scalar(sakura, scalar, use_decomposed_scalar)

            # Capture template trace
            file_name = "template_trace_k{}_{}".format(64, d_i)
            template_trace = capture_trace(sakura, save_to_file=False, file_name=file_name)
            # screen_capture(file_name)

            # Instead of capturing the template trace once, we capture it multiple times and take the average
            if average_template_signals:
                template_trace = capture_average_from_multiple_traces(sakura, template_trace, nr_of_additional_traces,
                                                                      channel="C3")

            # Store template trace and corresponding digit column + sign
            template_traces.append(template_trace)
            template_digit_columns.append(template_digit_column)
    return template_traces, template_digit_columns


def attack_digit_column(sakura, iteration, offsets, target_trace, attacked_digit_columns, use_decomposed_scalar=True,
                        average_template_signals=False, use_fft=False, use_points_of_interest=False, plot_intermediate_templates=False):
    """
    Perform the Online Template Attack to attack the digit columns and signs used in the given target trace
    :param average_template_signals:
    :param use_decomposed_scalar:
    :param use_points_of_interest: Whether to perform the correlation between template and target traces at Points of Interests (POIs)
    :param use_fft: Whether to use FFT before correlating the template traces with the target trace
    :param attacked_digit_columns: The previously attacked digit columns
    :param target_trace: The target trace
    :param sakura: The interface with the Sakura-G FPGA
    :param iteration: Indicates which digit column we are currently attacking (0 indicates digit column 63, 63 indicates
    digit column 0)
    :param offsets: The offsets in the target trace to the doubling operations
    :return: The recoded scalars aligned in matrix format that represent the scalar used in the scalar multiplication
    that resulted in the given target trace.
    """

    """
    Check whether this is the very first iteration of the template attack, as this iteration requires some special
    treatment. In this iteration, we attack the digit column K_64 (i.e. d_64. Note that we already know that s_64 = 1.
    Therefore, this case involves attacking three bits instead of 4.
    """
    is_first_iteration = iteration == 63
    is_last_iteration = iteration == 0

    dbl_offsets = [dbl_offset for idx, dbl_offset in enumerate(offsets) if idx % 2 == 0]
    add_offsets = [add_offset for idx, add_offset in enumerate(offsets) if idx % 2 == 1]

    # Obtain the template traces
    template_traces, template_digit_columns = obtain_template_traces(sakura, is_first_iteration, attacked_digit_columns,
                                                                     use_decomposed_scalar=use_decomposed_scalar,
                                                                     average_template_signals=average_template_signals)
    # Store the 'guessed' digit columns and their corresponding correlation coefficient
    correlation_results = []

    offset_idx = 63 - iteration

    offset_to_oper, duration_of_oper = dbl_offsets[offset_idx] if not is_last_iteration else add_offsets[offset_idx]

    # Determine Points of Interests if necessary
    # if use_points_of_interest:
    #     # TODO not sure if this is correct, as POIs need to be determined when taking all operations into account
    #     # TODO Currently, we only take operations in the current iteration into account
    #     # When need to make a deepcopy of the template traces, otherwise FFT will be applied two times
    #     # You can see that this happens by taking a look at the plot
    #     if use_fft:
    #         template_traces_for_oper = copy.deepcopy(template_traces)
    #         template_traces_for_oper = [apply_fft(template_trace[offset_to_oper:offset_to_oper + duration_of_oper]) for
    #                                     template_trace in template_traces_for_oper]
    #         points_of_interest = find_points_of_interest(np.asarray(template_traces_for_oper))
    #     else:
    #         template_traces_for_oper = copy.deepcopy(template_traces)
    #         template_traces_for_oper = [template_trace[offset_to_oper:offset_to_oper + duration_of_oper] for
    #                                     template_trace in template_traces_for_oper]
    #         points_of_interest = find_points_of_interest(np.asarray(template_traces_for_oper))

    saved_dbl_oper = not plot_intermediate_templates
    ctr = 0

    for template_trace, template_digit_column in zip(template_traces, template_digit_columns):
        # Experimenting with offsets into offsets
        offset_into_start = 0
        offset_from_end = 0
        # Determine which samples of the target and template trace will be correlated
        template_trace_dbl_oper = template_trace[
                                  offset_to_oper + offset_into_start: offset_to_oper + duration_of_oper - offset_from_end]
        target_trace_dbl_oper = target_trace[
                                offset_to_oper + offset_into_start: offset_to_oper + duration_of_oper - offset_from_end]

        if use_fft:
            template_trace_dbl_oper = apply_fft(template_trace_dbl_oper)
            target_trace_dbl_oper = apply_fft(target_trace_dbl_oper)

        # Store current doubling operation as a tsc file
        positive_digit_column = template_digit_column[0, 0] == 1
        file_name = "template_trace_dbl_oper_{}d{}_{}".format("+" if positive_digit_column else "-", iteration + 1, ctr)
        ctr += 1
        encoded_trace = _encode_as_trs(template_trace_dbl_oper, file_name)
        if plot_intermediate_templates:
            _store_trs_encoded_trace(encoded_trace, file_name)
            save_as_csv(template_trace_dbl_oper, file_name)

        # Save the corresponding doubling operation
        if not saved_dbl_oper and plot_intermediate_templates:
            file_name = "target_trace_dbl_oper_d{}".format(iteration + 1)
            encoded_trace = _encode_as_trs(target_trace_dbl_oper, file_name)
            _store_trs_encoded_trace(encoded_trace, file_name)
            save_as_csv(target_trace_dbl_oper, file_name)
            saved_dbl_oper = True

        # Only select samples at the Points of Interests if necessary
        # if use_points_of_interest:
        #     template_trace_dbl_oper = [sample for idx, sample in enumerate(template_trace_dbl_oper) if
        #                                idx in points_of_interest]
        #     target_trace_dbl_oper = [sample for idx, sample in enumerate(target_trace_dbl_oper) if
        #                              idx in points_of_interest]

        # Calculate the Pearson correlation coefficient between the template and target trace
        correlation_coeff = correlate(template_trace_dbl_oper, target_trace_dbl_oper)

        """
        if not the first and last iteration of the main loop, we can also use the addition operation
        in template matching.
        """
        if not is_first_iteration and not is_last_iteration:
            offset_to_add_oper, duration_of_add_oper = add_offsets[offset_idx - 1]
            template_trace_add_oper = template_trace[
                                      offset_to_add_oper + offset_into_start: offset_to_add_oper + duration_of_add_oper - offset_from_end]
            target_trace_add_oper = target_trace[
                                    offset_to_add_oper + offset_into_start: offset_to_add_oper + duration_of_add_oper - offset_from_end]
            add_correlation_coeff = correlate(template_trace_add_oper, target_trace_add_oper)

            correlation_coeff += add_correlation_coeff
            correlation_coeff /= 2

        # Save result such that we can determine later on which template had the highest correlation
        correlation_results.append((template_digit_column, correlation_coeff))

    # print(points_of_interest)
    if plot_intermediate_templates:
        cur_digit_col = "d{}".format(iteration + 1)
        overlap_file_name = "template_traces_overlap_d{}".format(iteration + 1)
        plot_traces_to_pdf(cur_digit_col)
        plot_traces_to_pdf(cur_digit_col, overlap=True, overlap_file_name=overlap_file_name)

    del template_traces
    gc.collect()
    return correlation_results


# TODO verify this function
def determine_points_of_interest(sakura, offsets, use_decomposed_scalar):
    """
    Determine the points of interest for the power trace for iteration 63 downto 0.
    :param use_decomposed_scalar:
    :param offsets: The offsets to each iteration
    :param sakura: The interface with the Sakura-G FPGA
    :return: The points of interest
    """
    # Generate 1000 random scalars m, and determine the points of interest using these scalars
    # We first group the ADD and DBL operations for each operation together
    # Then we determine the POIs for these grouped operations

    # A list containing tuples of lists
    grouped_operations = [([], [])] * 64

    dbl_offsets = [dbl_offset for idx, dbl_offset in enumerate(offsets) if idx % 2 == 0]
    add_offsets = [add_offset for idx, add_offset in enumerate(offsets) if idx % 2 == 1]
    scalars = np.arange(0, 1000)
    for scalar in scalars:
        # Load the scalar to the FPGA
        load_scalar(sakura, scalar, use_decomposed_scalar)
        # Capture the power trace
        power_trace = capture_trace(sakura)
        for i in range(64):
            # Extract the power trace of the DBL and ADD operations for the current iteration (0 is start)
            dbl_start, dbl_duration = dbl_offsets[i]
            add_start, add_duration = add_offsets[i]
            dbl_trace = power_trace[dbl_start:dbl_start + dbl_duration]
            add_trace = power_trace[add_start:add_start + add_duration]
            # First element in the tuple contains the DBL traces
            grouped_operations[i][0].append(dbl_trace)
            # Second element in the tuple contains the ADD traces
            grouped_operations[i][1].append(add_trace)

    # Now we can determine the points of interest in each iteration
    points_of_interest = []
    for dbl_opers, add_opers in grouped_operations:
        dbl_opers = np.asarray(dbl_opers)
        add_opers = np.asarray(add_opers)
        # Calculate POIs
        pois_dbl = find_points_of_interest(dbl_opers)
        pois_add = find_points_of_interest(add_opers)
        # Store POIs
        points_of_interest.append((pois_dbl, pois_add))


def find_points_of_interest(template_traces: np.ndarray):
    """
    Find the average power of the given template traces, and try to find the interesting points
    This is not according to the paper of Template Attacks, as we only have one operation for which we have multiple
    templates.
    :param template_traces: The template traces
    :return: The points of interest (as indices) for the given template traces
    """

    nr_of_traces = len(template_traces)
    sum_of_all_traces = np.sum(template_traces, axis=0)
    avg_power = 1 / nr_of_traces * sum_of_all_traces

    # # We only consider the real part of the imaginary number (if the traces have been processed by FFT)
    # avg_power = np.asarray(avg_power, dtype=np.int32)

    # Compute summation of difference between each trace and the avery.
    # Interesting points should have a higher spike in the result
    sum_of_diffs = np.zeros((len(avg_power),)) if template_traces.dtype != np.complex128 else np.zeros(
        (len(avg_power),), dtype=np.complex128)
    for template_trace in template_traces:
        all_positive = lambda sample: -sample if sample < 0 else sample
        template_trace = np.asarray(list(map(all_positive, template_trace)))
        template_trace = np.asarray(template_trace) if template_trace.dtype != np.complex128 else np.asarray(
            template_trace, dtype=np.complex128)
        sum_of_diffs += (template_trace - avg_power)

    file_name = "sum_of_diffs"
    encoded_trace = _encode_as_trs(sum_of_diffs, file_name)
    _store_trs_encoded_trace(encoded_trace, file_name)

    # TODO Determine which points are interesting and how many to select
    # TODO use clock period i.c.w sampling rate to determine samples per clock cycle
    argmax = np.argmax(sum_of_diffs)
    sum_of_diffs[argmax] = 0
    indices_points_of_interest = [argmax]
    points_to_select = 10
    min_spacing = 20
    while len(indices_points_of_interest) < points_to_select:
        argmax = np.argmax(sum_of_diffs)
        smallest_idx_distance = np.min(np.abs(indices_points_of_interest - argmax))
        if smallest_idx_distance >= min_spacing:
            indices_points_of_interest.append(argmax)
        sum_of_diffs[argmax] = 0

    return indices_points_of_interest


def perform_scalar_mult(sakura, without_cfk=True):
    """
    Perform the FourQ scalar multiplication by sending the appropriate instructions to the hardware implementation of
    FourQ.
    :param sakura: The interface with the Sakura-G FPGA
    :param without_cfk: Whether we perform the scalar multiplication with co-factor killing.
    :return: The result point of the scalar multiplication.
    """
    # Initialize
    sakura.write_operation(0x00, 0x01)

    # Wait until busy is done
    while sakura.is_busy():
        continue

    if not without_cfk:
        # Cofactor killing
        sakura.write_operation(0x00, 0x06)
        while sakura.is_busy():
            continue

    # Pre-computation + Scalar multiplication + Affine
    sakura.write_operation(0x00, 0x02)

    while sakura.is_busy():
        continue

    result_point = fourq_scalar_mult.fourq_read_result_point(sakura)
    return result_point


def load_scalar(sakura, scalar, use_decomposed_scalar):
    """
    Load the given scalar to the FPGA
    :param use_decomposed_scalar:
    :param scalar: The scalar to load to the FPGA
    :param sakura: The interface with the Sakura-G FPGA
    :return:
    """
    # Mask for selecting 64 bits
    # Note that scalars are loaded as HEX values
    if use_decomposed_scalar:
        # Load decomposed scalar
        a0, a1, a2, a3 = scalar
    else:
        # Load scalar
        mask = 0xFFFFFFFFFFFFFFFF
        a0, a1, a2, a3 = scalar & mask, (scalar >> 64) & mask, (scalar >> 128) & mask, (scalar >> 192) & mask
    scalar_to_load = [a0, a1, a2, a3]
    scalar_to_load = [hex(ai)[2:].zfill(16) for ai in scalar_to_load]
    fourq_scalar_mult.fourq_write_scalar(sakura, *scalar_to_load)


def save_target_trace(target_trace: np.ndarray, file_name="target_trace", directory="inspector_traces"):
    """
    Write the target trace to a file, for easy loading
    :param dir:
    :param file_name:
    :return:
    """
    path = files.get_full_path(directory, file_name + "")
    # See https://docs.python.org/3/library/string.html#format-specification-mini-language for fmt options
    np.save(path, target_trace)


def load_target_trace(file_name="target_trace", directory="inspector_traces"):
    """
    Load the target trace from a file.
    :return:
    """
    path = files.get_full_path(directory, file_name + ".npy")
    target_trace = np.load(path)
    return target_trace


def save_as_csv(trace, file_name, directory="inspector_traces"):
    csv_content = []
    for sample, value in enumerate(trace):
        csv_content.append((sample, value))
    csv_content = np.asarray(csv_content)
    path = files.get_full_path(directory, file_name + ".txt")
    np.savetxt(path, csv_content, fmt="%d, %d")


def capture_trace(sakura, channel="C3", without_cfk=True, save_to_file=False, file_name="my_power_trace"):
    """
    Capture a power trace from the oscilloscope. The setup is as follows:
    Three channels:
    - Trigger to C1 (which is destination J4)
    - FPGA acq. to C2 and C3, where C2 contains the signal used for calculating the offsets
    and C3 the actual power consumption of the FPGA
    :param sakura: The FPGA interface
    :param channel: The channel to capture from
    :param without_cfk: Whether to capture the trace with or without FourQ's cofactor killing enabled
    :param save_to_file: Whether to store the captured trace
    :param file_name: The file name if the trace is to be stored
    :return: The interpreted waveform captured form the given channel
    """
    # Prepare for capture
    lecroy_if.prepare_for_trace_capture()
    perform_scalar_mult(sakura, without_cfk)
    lecroy_if.wait_lecroy()
    channel_out_interpreted = lecroy_if.acquire_trace(channel)
    # Store trace to file
    if save_to_file:
        # Store in *.tsc format (Format specified by Inspector, see Appendix K of the Inspector manual)
        trs_file_content = _encode_as_trs(channel_out_interpreted, file_name)
        as_type = "byte"
        _store_trs_encoded_trace(trs_file_content, file_name)

    return channel_out_interpreted


def capture_average_from_multiple_traces(sakura, org_power_trace, nr_of_additional_traces, channel):
    """
    Capture a power trace multiple times and return the average signal
    :param sakura:
    :param org_power_trace:
    :param nr_of_additional_traces:
    :param channel:
    :return:
    """
    for i in range(nr_of_additional_traces):
        captured_trace = capture_trace(sakura, channel)
        min_lenght = min(len(captured_trace), len(org_power_trace))
        np.add(org_power_trace[:min_lenght], captured_trace[:min_lenght], out=org_power_trace[:min_lenght])
    org_power_trace = np.asarray(org_power_trace / (nr_of_additional_traces + 1), dtype=np.int32)
    return org_power_trace


def _encode_as_trs(trace: np.ndarray, file_name="my_power_trace"):
    """
    Encode a power trace in trs format
    :param trace:  The numpy array containing the power trace
    :param file_name:  The file name to be encoded into the trace
    :return:
    """
    # Store in *.tsc format (Format specified by Inspector, see Appendix K of the Inspector manual)
    trs_file_content = trace_set_encoder.to_trs_format([trace], [], [file_name],
                                                       len(trace),
                                                       0,  # integer format
                                                       1  # Sample length in bytes
                                                       )
    return trs_file_content


def _store_trs_encoded_trace(trs_encoded_trace, file_name):
    """
    Store a TRS encoded trace
    :param trs_encoded_trace: the powertrace encoded as TRC
    :param file_name: The file name to use when storing the file
    """
    dir = "inspector_traces"
    extension = ".trs"
    abs_path = files.get_full_path(dir, file_name + extension)
    os.makedirs(os.path.dirname(abs_path), exist_ok=True)
    with open(abs_path, "wb+") as f:
        f.write(trs_encoded_trace)


def save_trace_as_file(power_trace, file_name):
    """
    Store a given power trace as a TRS file
    :param power_trace:
    :param file_name:
    :return:
    """
    encoded_trace = _encode_as_trs(power_trace, file_name)
    _store_trs_encoded_trace(encoded_trace, file_name)


def _get_min_max_indices(trace: np.ndarray, threshold, nth_diff):
    """
    Determine the min and max indices for a given power trace using the given threshold
    :param trace: The power trace
    :param threshold: The threshold to use when determining the rising and falling edges
    :return: The local min and max indices for the given power trace
    """
    # Calculate the differences between consecutive elements of an array.
    diff_consec_vals = np.diff(trace, n=nth_diff)
    # Determine which values indicate a rising/falling edge (i.e. the start or end of a trigger)
    min_and_max_indices = np.where(abs(diff_consec_vals) > threshold)[0]
    # These indices are off by nth-diff compared to the values in the trigger trace,
    # out[n] = a[n+1] - a[n] thus we add n to each element in the array
    min_and_max_indices += nth_diff
    return min_and_max_indices


def determine_offsets_static(oper_trigger_trace, nth_diff):
    """
     If we generate a template for the corresponding operation in the target trace, we need to deal with offsets and such:
    * the offset to the first iteration
    * the offset after the start of an iteration to the operation we want to consider (i.e. the DLB operation)
    * the offset from the beginning to the end of the operation
    This function does exactly calculate these offsets
    :return:
    """
    # Determine the min and max indices for the operation trigger trace (indicating start/end of DBL/ADD)
    # First we zero out all low values in the trace
    # Average min and max values in the power trace
    min_val = np.min(oper_trigger_trace)
    max_val = np.max(oper_trigger_trace)
    min_max_avg = (min_val + max_val) / 2.0

    # Determine all values lower and higher than this average
    high_values_flag = oper_trigger_trace > min_max_avg
    low_values_flag = oper_trigger_trace <= min_max_avg
    trace_high = oper_trigger_trace[high_values_flag]
    trace_low = oper_trigger_trace[low_values_flag]

    # Determine Least Upper Bound and Greatest Lower Bound
    lub = np.min(trace_high)
    glb = np.max(trace_low)

    threshold = (lub + glb) / 2.0

    # Clip values above threshold to max and below to min
    above_threshold_flag = oper_trigger_trace > threshold
    below_threshold_flag = oper_trigger_trace <= threshold
    oper_trigger_trace[above_threshold_flag] = max_val
    oper_trigger_trace[below_threshold_flag] = min_val

    # save_trace_as_file(oper_trigger_trace, "oper_trigger_trace_modified")

    min_and_max_indices = _get_min_max_indices(oper_trigger_trace, threshold, nth_diff)

    # Calculate the offsets for both rising edges and their duration
    offsets = []
    for idx, min_max_idx in enumerate(min_and_max_indices):
        # Stop if we hit the last element in the list
        if idx == len(min_and_max_indices) - 1:
            break
        # Determine the between the two successive min/max indices
        next_min_max_idx = min_and_max_indices[idx + 1]
        duration = next_min_max_idx - min_max_idx
        # Only store the offsets if they belong to a rising edge
        if oper_trigger_trace[min_max_idx] >= threshold:
            offsets.append((min_max_idx, duration))
    return offsets


def apply_fft(power_trace):
    """
    Apply FFT to the given power trace
    :param power_trace: The power trace
    :return:
    """
    result = np.fft.fft(power_trace)
    return result


def correlate(template_doubling_trace, target_doubling_trace):
    """
    Correlate the template trace containing the doubling operation with the target trace and the corresponding doubling
    operation
    :param template_doubling_trace: The template trace of the doubling operation we want to attack.
    :param target_doubling_trace: The target trace of the doubling operation we want to attack.
    :return:
    """
    correlation_matrix = np.corrcoef(template_doubling_trace, target_doubling_trace)
    """
    This correlation matrix have 2 rows and 2 columns (with 1's on the diagonal).
    Its symmetric in the diagonal and both the second row and the first element or the first row and the second element
    contain the wanted correlation coefficient of the two input arrays.
    """
    return correlation_matrix[1, 0]


def plot_traces_to_pdf(digit_col: str, dir="inspector_traces", overlap=False, overlap_file_name="plot_templates_overlap"):
    """
    Plot a trace and store as PDF using Matplotlib
    Relevant links are as follows:
    - https://stackoverflow.com/questions/42372617/how-to-plot-csv-data-using-myplotlib-and-pandas-in-python
    - Save as PDF: https://stackoverflow.com/questions/11328958/save-the-plots-into-a-pdf
    - Figure is blank: https://stackoverflow.com/questions/9012487/matplotlib-pyplot-savefig-outputs-blank-image
    :param overlap: Whether to overlap multiple waveforms plots into a single plot
    :param dir: In which directory to store
    :return:
    """
    import pandas as pd
    import matplotlib.pyplot as plt
    headers = ["Sample", "Volt"]

    # Change to the directory that contains the csv files
    os.chdir(files.get_full_path(dir))

    """
    Find the N most distincitve colors for a given color palette.
    Read more on these links:
    - https://stackoverflow.com/q/8389636
    - https://stats.stackexchange.com/q/118033
    """


    csv_files = glob.glob("*.txt")
    # Only plot csv files that are related to the current iteration of the algorithm
    if overlap:
        csv_files = [csv_file for csv_file in csv_files if digit_col in csv_file and not ("target" in csv_file)]
    else:
        csv_files = [csv_file for csv_file in csv_files if digit_col in csv_file]
    # The max number of templates in one iteration is 16, just to verify
    assert len(csv_files) <= 17

    # Define the color map
    NUM_COLORS = len(csv_files)
    # See https://matplotlib.org/users/colormaps.html for the available color maps
    cm = plt.get_cmap('viridis')
    plt.gca().set_prop_cycle(color=[cm(1. * i / NUM_COLORS) for i in range(NUM_COLORS)])

    # Loop through all the csv files in the directory and plot them
    for idx, csv_file in enumerate(csv_files):
        path = files.get_full_path(dir, csv_file)
        df = pd.read_csv(path, names=headers)

        x = df['Sample']
        y = df['Volt']
        # plot

        almost_black = "#262626"
        if not overlap or idx == 0:
            plt.figure(figsize=(10, 3))
        if not overlap:
            plt.plot(x, y, linewidth=0.3, color="blue")
        else:

            plt.plot(x, y, linewidth=0.1, alpha=0.5, label="d{}".format(idx))

        # Remove top axes and right axes
        for spine in ["top", "right"]:
            plt.gca().spines[spine].set_visible(False)

        # For remaining spines, thin out their line and change the black to a slightly off-black dark grey
        spines_to_keep = ['bottom', 'left']
        for spine in spines_to_keep:
            plt.gca().spines[spine].set_linewidth(0.5)
            plt.gca().spines[spine].set_color(almost_black)
        # beautify the x-labels
        plt.gcf().autofmt_xdate()
        plt.tight_layout()
        csv_file_name = os.path.splitext(csv_file)[0]
        if not overlap:
            plt.savefig(csv_file_name + ".pdf", bbox_inches='tight')

    if overlap:
        plt.legend(loc="upper right")
        # set the linewidth of each legend object
        plt.gca().legend(loc="center left", bbox_to_anchor=(1, 0.5))
        for line in plt.gca().get_legend().get_lines():
            line.set_linewidth(4.0)
        plt.savefig(overlap_file_name + ".pdf", bbox_inches='tight')

    plt.close("all")


def prepare_ota():
    # Connect to LeCroy
    global lecroy_if
    lecroy_if = lecroy_interface.Lecroy()

    gc.enable()
    use_decomposed_scalar = True
    recapture_target_trace = False
    average_template_signals = True
    plot_intermediate_templates = False

    # First test vector in the test vectors provided by the hardware implementation
    p_x = (4278750285544105074676860908476659235, 129913138569548007992917457078809919071)
    p_y = (18212526546888401742587968450932351321, 43058747546351419525605575024245364232)
    base_point = (p_x, p_y)

    decomposed_scalar = [0x8b8e05ff76fe90a5, 0x6261ed79303c3feb, 0x780e38de51089170, 0x5f055848a6493e4f]
    k1, k2, k3, k4 = decomposed_scalar
    if use_decomposed_scalar:
        scalar_to_attack = decomposed_scalar
    else:
        # k1, k2, k3, k4 = [5592475829050469997, 13327419138273583453, 2309149956473561138, 5859400630064857171]
        scalar_to_attack = k4 << 192 | k3 << 128 | k2 << 64 | k1

    start_time = time.time()
    print("Time start: {}".format(datetime.datetime.now().strftime("%a, %d %B %Y %H:%M:%S")))

    # Best way to verify these values is to call the "get_panel" method and lookup the values for a given channel
    # (bandwidth, VerScale, VerOffset
    # set_bandwidth, set_volt_per_div, set_vertical_offset
    settings = [
        ("20MHZ", 3.4e-3, 7.0e-3),
        ("200MHZ", 4.0e-3, 8.2e-3),
        ("OFF", 5.10e-3, 6.0e-3)
    ]

    for oscilloscope_settings in settings[:1]:
        bandwidth, ver_scale, ver_offset = oscilloscope_settings
        # Set the appropriate settings
        # lecroy_if.set_bandwidth_limit("C3", bandwidth)
        # lecroy_if.set_volts_div("C3", ver_scale)
        # lecroy_if.set_vertical_offset("C3", ver_scale)
        for additional_traces in [50]:
            global nr_of_additional_traces
            nr_of_additional_traces = additional_traces
            ranks_per_iter = []
            if average_template_signals:
                print("Nr of additional template traces: {}".format(nr_of_additional_traces))
            if recapture_target_trace:
                print("Recapture target trace: {}".format(recapture_target_trace))
            for i in range(10):
                # online_template_attack launches the attack
                rank_per_iter = online_template_attack(base_point, scalar_to_attack,
                                                       use_decomposed_scalar=use_decomposed_scalar,
                                                       average_template_signals=average_template_signals,
                                                       max_nr_of_iterations=4,
                                                       recapture_target_trace=recapture_target_trace,
                                                       plot_intermediate_templates=plot_intermediate_templates,
                                                       enable_output=False
                                                       )
                gc.collect()
                ranks_per_iter.append(rank_per_iter)
                recapture_target_trace &= False
                print("Iteration {}, Recapture target trace: {}".format(i, recapture_target_trace))
            ranks_per_iter = np.array(ranks_per_iter)

            # Group ranks of same iteration together, print there standard deviation and average
            print("Time end: {}".format(datetime.datetime.now().strftime("%a, %d %B %Y %H:%M:%S")))
            print("Elapsed time: {}".format((time.time() - start_time) / 60))
            print("\nSTART OF RESULTS")
            for i in range(ranks_per_iter.shape[1]):
                column = ranks_per_iter[:, i]
                avg = np.average(column)
                print("Average rank of ranks in iteration {} : {}".format(63 - i, avg))
                median = np.median(column)
                print("Median rank of ranks in iteration {} : {}".format(63 - i, median))
                std_dev = np.std(column)
                print("Standard deviation of rank in ranks of iteration {} : {}".format(63 - i, std_dev))
                print("Min value: {}".format(np.min(column)))
                print("Max value: {}".format(np.max(column)))

            # Statistics for the settings as a whole
            ranks_per_iter = ranks_per_iter.flatten()
            avg = np.average(ranks_per_iter)
            median = np.median(ranks_per_iter)
            std_dev = np.std(ranks_per_iter)
            min_val = np.min(ranks_per_iter)
            max_val = np.max(ranks_per_iter)
            print()
            print("--------------------------")
            print("FINAL RESULTS")
            print("--------------------------")
            print("Average:\t {}".format(avg))
            print("Median: \t {}".format(median))
            print("Standard dev:\t {}".format(std_dev))
            print("Nr of times guessed correctly:\t {}".format(np.count_nonzero(ranks_per_iter == 1)))
            print("END OF RESULTS")


if __name__ == "__main__":
    # TODO code causes memory error, see this post and the corresponding answers: https://stackoverflow.com/q/4318615
    # TODO look into memory-mapped arrays numpy, see https://stackoverflow.com/q/5537618
    # This seems to be the answer: https://stackoverflow.com/questions/36749082/load-np-memmap-without-knowing-shape
    # https://stackoverflow.com/questions/4335289/how-can-i-create-a-numpy-npy-file-in-place-on-disk
    prepare_ota()
