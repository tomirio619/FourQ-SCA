from utils import files
import os


def determine_offsets(exec_log, isim_log):
    intermediate_vals = parse_exec_log(exec_log)
    parsed_isim_log = parse_isim_log(isim_log)
    intermediate_vals_dbl_start, intermediate_vals_dbl_end, intermediate_vals_add_start, \
    intermediate_vals_add_end = intermediate_vals

    prog_cntr_dbl_start = []
    prog_cntr_dbl_end = []
    prog_cntr_add_start = []
    prog_cntr_add_end = []

    # Math values for each of the intermediate values with the program counter in the isim log

    # Start of doubling operation
    for idx, vals_dbl_start in enumerate(intermediate_vals_dbl_start):
        prog_cntrs_per_iter = []
        for val_dbl_start in vals_dbl_start:
            # strip leading 0x and trailing 'L' from the hex value
            val_dbl_start = val_dbl_start[2:-1]
            prog_cntrs = match_operation_val(val_dbl_start, parsed_isim_log[idx])
            prog_cntrs_per_iter.append(prog_cntrs)
        prog_cntr_dbl_start.append(prog_cntrs_per_iter)

    # End of doubling operation
    for idx, vals_dlb_end in enumerate(intermediate_vals_dbl_end):
        prog_cntrs_per_iter = []
        for val_dbl_end in vals_dlb_end:
            # strip leading 0x and trailing 'L' from the hex value
            val_dbl_end = val_dbl_end[2:-1]
            prog_cntrs = match_operation_val(val_dbl_end, parsed_isim_log[idx])
            prog_cntrs_per_iter.append(prog_cntrs)
        prog_cntr_dbl_end.append(prog_cntrs_per_iter)

    # Start of addition operation
    for idx, vals_add_start in enumerate(intermediate_vals_add_start):
        prog_cntrs_per_iter = []
        for val_add_start in vals_add_start:
            # strip leading 0x and trailing 'L' from the hex value
            val_add_start = val_add_start[2:-1]
            prog_cntrs = match_operation_val(val_add_start, parsed_isim_log[idx])
            prog_cntrs_per_iter.append(prog_cntrs)
        prog_cntr_add_start.append(prog_cntrs_per_iter)

    # End of addition operation
    for idx, vals_add_end in enumerate(intermediate_vals_add_end):
        prog_cntrs_per_iter = []
        for val_add_end in vals_add_end:
            # strip leading 0x and trailing 'L' from the hex value
            val_add_end = val_add_end[2:-1]
            prog_cntrs = match_operation_val(val_add_end, parsed_isim_log[idx])
            prog_cntrs_per_iter.append(prog_cntrs)
        prog_cntr_add_end.append(prog_cntrs_per_iter)
    todo = 1


def match_operation_val(operation_val, iteration_log):
    # Find indices where the operation value appears in the iteration log
    log_indices = [i for i, iter_log_line in enumerate(iteration_log) if operation_val.upper() in iter_log_line]
    # ADD_core has values 0x2L and 0x0L, which we ignore as it is tough to find these values
    if len(log_indices) == 0 or operation_val == "0" or operation_val == '2':
        return []

    prog_cntrs = []
    # The line after the one that contains the value points to the correct program counter value
    for log_idx in log_indices:
        iteration_log_line = iteration_log[log_idx + 1]
        prog_cntr = get_prog_cntr_from_line(iteration_log_line)
        prog_cntrs.append(prog_cntr)

    return prog_cntrs


def get_prog_cntr_from_line(iteration_log_line):
    # A typical line will look as follows:
    # 'at 5903678474 ps(2): Note: program counter: 4373'
    # So we split at the ':' and take the last element
    splitted = iteration_log_line.split(':')
    splitted = splitted[-1].split(' ')
    # Remove empty strings
    splitted = [x for x in splitted if x]
    prog_cntr = splitted[0]
    return prog_cntr


def load_log(filename):
    dir = "fourq_exec_logs"
    full_path = files.get_full_path(os.path.join(dir, filename))
    with open(full_path) as f:
        content = f.readlines()
    content = [x.strip() for x in content]
    return content


def parse_isim_log(isim_log):
    iteration_starts_with = "Digit counter:"
    indices_to_split = [i for i, x in enumerate(isim_log) if iteration_starts_with in x]
    iterations = []
    for idx, idx_to_split in enumerate(indices_to_split):
        # first index takes everything till its index
        if idx == 0:
            iteration = isim_log[:idx_to_split]
        # Take value between successive indices
        else:
            prev_idx_to_split = indices_to_split[idx - 1]
            iteration = isim_log[prev_idx_to_split:idx_to_split]
        iterations.append(iteration)

    # last index takes everything from its index
    idx_to_split = indices_to_split[-1]
    iteration = isim_log[idx_to_split:]
    iterations.append(iteration)
    return iterations


def parse_exec_log(exec_log):
    intermediate_vals_dbl_start = []
    intermediate_vals_dbl_end = []
    intermediate_vals_add_start = []
    intermediate_vals_add_end = []

    dbl_start_begin = "DBL begin start values"
    dbl_start_end = "DBL end start values"
    dbl_end_start = "DBL begin end values"
    dbl_end_end = "DBL end end values"

    add_start_begin = "ADD_core begin start values"
    add_start_end = "ADD_core end start values"
    add_end_start = "ADD_core begin end values"
    add_end_end = "ADD_core end end values"

    ctr = 0
    while ctr < len(exec_log):
        line = exec_log[ctr]
        if line == dbl_start_begin:
            end = exec_log[ctr:].index(dbl_start_end)
            intermediate_val_dbl_start = exec_log[ctr + 1: ctr + end]
            intermediate_vals_dbl_start.append(intermediate_val_dbl_start)
        elif line == dbl_end_start:
            end = exec_log[ctr:].index(dbl_end_end)
            intermediate_val_dbl_end = exec_log[ctr + 1: ctr + end]
            intermediate_vals_dbl_end.append(intermediate_val_dbl_end)
        elif line == add_start_begin:
            end = exec_log[ctr:].index(add_start_end)
            intermediate_val_add_start = exec_log[ctr + 1: ctr + end]
            intermediate_vals_add_start.append(intermediate_val_add_start)
        elif line == add_end_start:
            end = exec_log[ctr:].index(add_end_end)
            intermediate_val_add_end = exec_log[ctr + 1: ctr + end]
            intermediate_vals_add_end.append(intermediate_val_add_end)
        else:
            ctr += 1
            continue
        ctr += end + 1
    return intermediate_vals_dbl_start, intermediate_vals_dbl_end, intermediate_vals_add_start, intermediate_vals_add_end


if __name__ == "__main__":
    exec_log = load_log("exec_log_3_single_squaring.txt")
    isim_log = load_log("isim_log_1.txt")
    determine_offsets(exec_log, isim_log)
