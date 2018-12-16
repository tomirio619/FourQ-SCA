// please add this lines on main.c (196) and enable hardware cryptoprocessor

		case (0xCB):
			get_bytes(16, rxBuffer);
			int cr = 0; int tr = 120;
			for (cr = 0; cr < tr; cr++)
			{
				for (i = 128; i < RXBUFFERLENGTH; i++) rxBuffer[i] = 0; //Zero the rxBuffer
				//Trigger pin handling moved to CRYP_AES_ECB function
				cryptoCompletedOK = CRYP_AES_ECB(MODE_ENCRYPT, keyAES, 128,	rxBuffer, (uint32_t) AES128LENGTHINBYTES, rxBuffer + AES128LENGTHINBYTES);
			}
			if (cryptoCompletedOK == SUCCESS) {
				send_bytes(16, rxBuffer + AES128LENGTHINBYTES);
			} else {
				send_bytes(16, zeros);
			}
		break;