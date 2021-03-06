rom_values = [
    # (lower half, upper half, ram_address)
    ('0000000000000000', '0000000000000000', 0x60),  # zero
    ('0000000000000001', '0000000000000000', 0x61),  # one
    ('0000000000000142', '00000000000000e4', 0x1e),  # d imaginary
    ('b3821488f1fc0c8d', '5e472f846657e0fc', 0x1f),  # d real
    ('74dcd57cebce74c3', '1964de2c3afad20c', 0x20),  # ctau1
    ('0000000000000012', '000000000000000c', 0x21),  # ctau1 cont
    ('9ecaa6d9decdf034', '4aa740eb23058652', 0x22),  # ctaud1
    ('0000000000000011', '7ffffffffffffff4', 0x23),  # ctaud1 cont
    ('edf07f4767e346ef', '2af99e9a83d54a02', 0x24),  # cpsi1
    ('000000000000013a', '00000000000000de', 0x25),  # cpsi1 cont
    ('0000000000000143', '00000000000000e4', 0x26),  # cpsi2
    ('4c7deb770e03f372', '21b8d07b99a81f03', 0x27),  # cpsi2 cont
    ('0000000000000009', '0000000000000006', 0x28),  # cpsi3
    ('3a6e6abe75e73a61', '4cb26f161d7d6906', 0x29),  # cpsi3 cont
    ('fffffffffffffff6', '7ffffffffffffff9', 0x2a),  # cpsi4
    ('c59195418a18c59e', '334d90e9e28296f9', 0x2b),  # cpsi4 cont
    ('fffffffffffffff7', '0000000000000005', 0x2c),  # cphi0
    ('4f65536cef66f81a', '2553a0759182c329', 0x2d),  # cphi0 cont
    ('0000000000000007', '0000000000000005', 0x2e),  # cphi1
    ('334d90e9e28296f9', '62c8caa0c50c62cf', 0x2f),  # cphi1 cont
    ('0000000000000015', '000000000000000f', 0x30),  # cphi2
    ('2c2cb7154f1df391', '78df262b6c9b5c98', 0x31),  # cphi2 cont
    ('0000000000000003', '0000000000000002', 0x32),  # cphi3
    ('92440457a7962ea4', '5084c6491d76342a', 0x33),  # cphi3 cont
    ('0000000000000003', '0000000000000003', 0x34),  # cphi4
    ('a1098c923aec6855', '12440457a7962ea4', 0x35),  # cphi4 cont
    ('000000000000000f', '000000000000000a', 0x36),  # cphi5
    ('669b21d3c5052df3', '459195418a18c59e', 0x37),  # cphi5 cont
    ('0000000000000018', '0000000000000012', 0x38),  # cphi6
    ('cd3643a78a0a5be7', '0b232a8314318b3c', 0x39),  # cphi6 cont
    ('0000000000000023', '0000000000000018', 0x3a),  # cphi7
    ('66c183035f48781a', '3963bc1c99e2ea1a', 0x3b),  # cphi7 cont
    ('00000000000000f0', '00000000000000aa', 0x3c),  # cphi8
    ('44e251582b5d0ef0', '1f529f860316cbe5', 0x3d),  # cphi8 cont
    ('0000000000000bef', '0000000000000870', 0x3e),  # cphi9
    ('014d3e48976e2505', '0fd52e9cfe00375b', 0x3f),  # cphi9 cont
]