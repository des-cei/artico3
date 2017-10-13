# ----------------------------------------------------------------------------
#     _____
#    /     \
#   /____   \____
#  / \===\   \==/
# /___\===\___\/  AVNET Design Resource Center
#      \======/         www.em.avnet.com/drc
#       \====/    
# ----------------------------------------------------------------------------
#  
#  This design is the property of Avnet.  Publication of this
#  design is not authorized without written consent from Avnet.
#  
# 
#  Disclaimer:
#     Avnet, Inc. makes no warranty for the use of this code or design.
#     This code is provided  "As Is". Avnet, Inc assumes no responsibility for
#     any errors, which may appear in this code, nor does it make a commitment
#     to update the information contained herein. Avnet, Inc specifically
#     disclaims any implied warranties of fitness for a particular purpose.
#                      Copyright(c) 2009 Avnet, Inc.
#                              All rights reserved.
# 
# ----------------------------------------------------------------------------
 
 
## 200MHz System Clock
set_property LOC F14 [ get_ports CLK_N]
set_property IOSTANDARD LVDS [ get_ports CLK_N]

set_property LOC F15 [ get_ports CLK_P]
set_property IOSTANDARD LVDS [ get_ports CLK_P]



## ARM PJTAG Header
set_property LOC AB19 [ get_ports PJTAG_TCK]
set_property IOSTANDARD LVCMOS25 [ get_ports PJTAG_TCK]

set_property LOC AA20 [ get_ports PJTAG_TMS]
set_property IOSTANDARD LVCMOS25 [ get_ports PJTAG_TMS]

set_property LOC Y20 [ get_ports PJTAG_TD_I]
set_property IOSTANDARD LVCMOS25 [ get_ports PJTAG_TD_I]

set_property LOC AB20 [ get_ports PJTAG_TD_O]
set_property IOSTANDARD LVCMOS25 [ get_ports PJTAG_TD_O]



## CDCM61001 LVDS Clock Synthesizer
set_property LOC AF10 [ get_ports LVDS_CLK_P]
set_property IOSTANDARD LVDS [ get_ports LVDS_CLK_P]

set_property LOC AF9 [ get_ports LVDS_CLK_N]
set_property IOSTANDARD LVDS [ get_ports LVDS_CLK_N]

set_property LOC AD19 [ get_ports CDCM_OD0]
set_property IOSTANDARD LVCMOS25 [ get_ports CDCM_OD0]

set_property LOC AC18 [ get_ports CDCM_OD1]
set_property IOSTANDARD LVCMOS25 [ get_ports CDCM_OD1]

set_property LOC AD18 [ get_ports CDCM_OD2]
set_property IOSTANDARD LVCMOS25 [ get_ports CDCM_OD2]

set_property LOC AC19 [ get_ports CDCM_PR0]
set_property IOSTANDARD LVCMOS25 [ get_ports CDCM_PR0]

set_property LOC AA19 [ get_ports CDCM_PR1]
set_property IOSTANDARD LVCMOS25 [ get_ports CDCM_PR1]

set_property LOC AA18 [ get_ports CDCM_RST_N]
set_property IOSTANDARD LVCMOS25 [ get_ports CDCM_RST_N]




## Parallel Flash
set_property LOC C8 [ get_ports Linear_Flash_address_out[26]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_address_out[26]]

set_property LOC B6 [ get_ports Linear_Flash_address_out[25]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_address_out[25]]

set_property LOC K8 [ get_ports Linear_Flash_address_out[24]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_address_out[24]]

set_property LOC M10 [ get_ports Linear_Flash_address_out[23]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_address_out[23]]

set_property LOC B7 [ get_ports Linear_Flash_address_out[22]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_address_out[22]]

set_property LOC D9 [ get_ports Linear_Flash_address_out[21]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_address_out[21]]

set_property LOC C6 [ get_ports Linear_Flash_address_out[20]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_address_out[20]]

set_property LOC C9 [ get_ports Linear_Flash_address_out[19]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_address_out[19]]

set_property LOC A7 [ get_ports Linear_Flash_address_out[18]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_address_out[18]]

set_property LOC E10 [ get_ports Linear_Flash_address_out[17]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_address_out[17]]

set_property LOC E8 [ get_ports Linear_Flash_address_out[16]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_address_out[16]]

set_property LOC D8 [ get_ports Linear_Flash_address_out[15]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_address_out[15]]

set_property LOC C7 [ get_ports Linear_Flash_address_out[14]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_address_out[14]]

set_property LOC A8 [ get_ports Linear_Flash_address_out[13]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_address_out[13]]

set_property LOC E11 [ get_ports Linear_Flash_address_out[12]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_address_out[12]]

set_property LOC F9 [ get_ports Linear_Flash_address_out[11]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_address_out[11]]

set_property LOC F10 [ get_ports Linear_Flash_address_out[10]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_address_out[10]]

set_property LOC D11 [ get_ports Linear_Flash_address_out[9]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_address_out[9]]

set_property LOC B9 [ get_ports Linear_Flash_address_out[8]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_address_out[8]]

set_property LOC G11 [ get_ports Linear_Flash_address_out[7]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_address_out[7]]

set_property LOC A10 [ get_ports Linear_Flash_address_out[6]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_address_out[6]]

set_property LOC F8 [ get_ports Linear_Flash_address_out[5]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_address_out[5]]

set_property LOC F7 [ get_ports Linear_Flash_address_out[4]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_address_out[4]]

set_property LOC D6 [ get_ports Linear_Flash_address_out[3]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_address_out[3]]

set_property LOC D10 [ get_ports Linear_Flash_address_out[2]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_address_out[2]]

set_property LOC A9 [ get_ports Linear_Flash_address_out[1]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_address_out[1]]

set_property LOC G7 [ get_ports Linear_Flash_adv_ldn]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_adv_ldn]

set_property LOC B10 [ get_ports Linear_Flash_ce_n[0]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_ce_n[0]]

set_property LOC G9 [ get_ports Linear_Flash_data_io[15]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_data_io[15]]

set_property LOC J8 [ get_ports Linear_Flash_data_io[14]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_data_io[14]]

set_property LOC L7 [ get_ports Linear_Flash_data_io[13]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_data_io[13]]

set_property LOC H7 [ get_ports Linear_Flash_data_io[12]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_data_io[12]]

set_property LOC L8 [ get_ports Linear_Flash_data_io[11]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_data_io[11]]

set_property LOC L9 [ get_ports Linear_Flash_data_io[10]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_data_io[10]]

set_property LOC H11 [ get_ports Linear_Flash_data_io[9]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_data_io[9]]

set_property LOC G10 [ get_ports Linear_Flash_data_io[8]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_data_io[8]]

set_property LOC K7 [ get_ports Linear_Flash_data_io[7]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_data_io[7]]

set_property LOC J10 [ get_ports Linear_Flash_data_io[6]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_data_io[6]]

set_property LOC K10 [ get_ports Linear_Flash_data_io[5]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_data_io[5]]

set_property LOC J11 [ get_ports Linear_Flash_data_io[4]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_data_io[4]]

set_property LOC K12 [ get_ports Linear_Flash_data_io[3]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_data_io[3]]

set_property LOC L10 [ get_ports Linear_Flash_data_io[2]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_data_io[2]]

set_property LOC H12 [ get_ports Linear_Flash_data_io[1]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_data_io[1]]

set_property LOC L12 [ get_ports Linear_Flash_data_io[0]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_data_io[0]]

set_property LOC H8 [ get_ports Linear_Flash_oe_n[0]]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_oe_n[0]]

set_property LOC J9 [ get_ports Linear_Flash_we_n]
set_property IOSTANDARD LVCMOS18 [ get_ports Linear_Flash_we_n]



##  JX1 Connector - Please modify the I/O standards when using the JX1 signals as single-ended.
set_property LOC AD9 [ get_ports JX1_MGTREFCLK_N]
set_property IOSTANDARD LVDS [ get_ports JX1_MGTREFCLK_N]

set_property LOC AD10 [ get_ports JX1_MGTREFCLK_P]
set_property IOSTANDARD LVDS [ get_ports JX1_MGTREFCLK_P]

set_property LOC AF22 [ get_ports JX1_DIFF_CLKIN_N]
set_property IOSTANDARD LVDS [ get_ports JX1_DIFF_CLKIN_N]

set_property LOC AE22 [ get_ports JX1_DIFF_CLKIN_P]
set_property IOSTANDARD LVDS [ get_ports JX1_DIFF_CLKIN_P]

set_property LOC AH21 [ get_ports JX1_DIFF_RCLKIN_N]
set_property IOSTANDARD LVDS [ get_ports JX1_DIFF_RCLKIN_N]

set_property LOC AG21 [ get_ports JX1_DIFF_RCLKIN_P]
set_property IOSTANDARD LVDS [ get_ports JX1_DIFF_RCLKIN_P]

set_property LOC AJ19 [ get_ports JX1_DIFF_IO_0_N]
set_property IOSTANDARD LVDS [ get_ports JX1_DIFF_IO_0_N]

set_property LOC AH19 [ get_ports JX1_DIFF_IO_0_P]
set_property IOSTANDARD LVDS [ get_ports JX1_DIFF_IO_0_P]

set_property LOC AK18 [ get_ports JX1_DIFF_IO_1_N]
set_property IOSTANDARD LVDS [ get_ports JX1_DIFF_IO_1_N]

set_property LOC AK17 [ get_ports JX1_DIFF_IO_1_P]
set_property IOSTANDARD LVDS [ get_ports JX1_DIFF_IO_1_P]

set_property LOC AG20 [ get_ports JX1_DIFF_IO_2_N]
set_property IOSTANDARD LVDS [ get_ports JX1_DIFF_IO_2_N]

set_property LOC AF20 [ get_ports JX1_DIFF_IO_2_P]
set_property IOSTANDARD LVDS [ get_ports JX1_DIFF_IO_2_P]

set_property LOC AK23 [ get_ports JX1_DIFF_IO_3_N]
set_property IOSTANDARD LVDS [ get_ports JX1_DIFF_IO_3_N]

set_property LOC AK22 [ get_ports JX1_DIFF_IO_3_P]
set_property IOSTANDARD LVDS [ get_ports JX1_DIFF_IO_3_P]

set_property LOC AK20 [ get_ports JX1_DIFF_IO_4_N]
set_property IOSTANDARD LVDS [ get_ports JX1_DIFF_IO_4_N]

set_property LOC AJ20 [ get_ports JX1_DIFF_IO_4_P]
set_property IOSTANDARD LVDS [ get_ports JX1_DIFF_IO_4_P]

set_property LOC AJ24 [ get_ports JX1_DIFF_IO_5_N]
set_property IOSTANDARD LVDS [ get_ports JX1_DIFF_IO_5_N]

set_property LOC AJ23 [ get_ports JX1_DIFF_IO_5_P]
set_property IOSTANDARD LVDS [ get_ports JX1_DIFF_IO_5_P]

set_property LOC AK21 [ get_ports JX1_DIFF_IO_6_N]
set_property IOSTANDARD LVDS [ get_ports JX1_DIFF_IO_6_N]

set_property LOC AJ21 [ get_ports JX1_DIFF_IO_6_P]
set_property IOSTANDARD LVDS [ get_ports JX1_DIFF_IO_6_P]

set_property LOC AH24 [ get_ports JX1_DIFF_IO_7_N]
set_property IOSTANDARD LVDS [ get_ports JX1_DIFF_IO_7_N]

set_property LOC AH23 [ get_ports JX1_DIFF_IO_7_P]
set_property IOSTANDARD LVDS [ get_ports JX1_DIFF_IO_7_P]

set_property LOC AE21 [ get_ports JX1_DIFF_IO_8_N]
set_property IOSTANDARD LVDS [ get_ports JX1_DIFF_IO_8_N]

set_property LOC AD21 [ get_ports JX1_DIFF_IO_8_P]
set_property IOSTANDARD LVDS [ get_ports JX1_DIFF_IO_8_P]

set_property LOC AK25 [ get_ports JX1_DIFF_IO_9_N]
set_property IOSTANDARD LVDS [ get_ports JX1_DIFF_IO_9_N]

set_property LOC AJ25 [ get_ports JX1_DIFF_IO_9_P]
set_property IOSTANDARD LVDS [ get_ports JX1_DIFF_IO_9_P]

set_property LOC AE23 [ get_ports JX1_DIFF_IO_10_N]
set_property IOSTANDARD LVDS [ get_ports JX1_DIFF_IO_10_N]

set_property LOC AD23 [ get_ports JX1_DIFF_IO_10_P]
set_property IOSTANDARD LVDS [ get_ports JX1_DIFF_IO_10_P]

set_property LOC AD24 [ get_ports JX1_DIFF_IO_11_N]
set_property IOSTANDARD LVDS [ get_ports JX1_DIFF_IO_11_N]

set_property LOC AC24 [ get_ports JX1_DIFF_IO_11_P]
set_property IOSTANDARD LVDS [ get_ports JX1_DIFF_IO_11_P]

set_property LOC AF24 [ get_ports JX1_DIFF_IO_12_N]
set_property IOSTANDARD LVDS [ get_ports JX1_DIFF_IO_12_N]

set_property LOC AF23 [ get_ports JX1_DIFF_IO_12_P]
set_property IOSTANDARD LVDS [ get_ports JX1_DIFF_IO_12_P]

set_property LOC AG25 [ get_ports JX1_DIFF_IO_13_N]
set_property IOSTANDARD LVDS [ get_ports JX1_DIFF_IO_13_N]

set_property LOC AG24 [ get_ports JX1_DIFF_IO_13_P]
set_property IOSTANDARD LVDS [ get_ports JX1_DIFF_IO_13_P]

set_property LOC AH9 [ get_ports JX1_MGTRX0_N]
set_property IOSTANDARD LVDS [ get_ports JX1_MGTRX0_N]

set_property LOC AH10 [ get_ports JX1_MGTRX0_P]
set_property IOSTANDARD LVDS [ get_ports JX1_MGTRX0_P]

set_property LOC AJ7 [ get_ports JX1_MGTRX1_N]
set_property IOSTANDARD LVDS [ get_ports JX1_MGTRX1_N]

set_property LOC AJ8 [ get_ports JX1_MGTRX1_P]
set_property IOSTANDARD LVDS [ get_ports JX1_MGTRX1_P]

set_property LOC AG7 [ get_ports JX1_MGTRX2_N]
set_property IOSTANDARD LVDS [ get_ports JX1_MGTRX2_N]

set_property LOC AG8 [ get_ports JX1_MGTRX2_P]
set_property IOSTANDARD LVDS [ get_ports JX1_MGTRX2_P]

set_property LOC AE7 [ get_ports JX1_MGTRX3_N]
set_property IOSTANDARD LVDS [ get_ports JX1_MGTRX3_N]

set_property LOC AE8 [ get_ports JX1_MGTRX3_P]
set_property IOSTANDARD LVDS [ get_ports JX1_MGTRX3_P]

set_property LOC AK9 [ get_ports JX1_MGTTX0_N]
set_property IOSTANDARD LVDS [ get_ports JX1_MGTTX0_N]

set_property LOC AK10 [ get_ports JX1_MGTTX0_P]
set_property IOSTANDARD LVDS [ get_ports JX1_MGTTX0_P]

set_property LOC AK5 [ get_ports JX1_MGTTX1_N]
set_property IOSTANDARD LVDS [ get_ports JX1_MGTTX1_N]

set_property LOC AK6 [ get_ports JX1_MGTTX1_P]
set_property IOSTANDARD LVDS [ get_ports JX1_MGTTX1_P]

set_property LOC AJ3 [ get_ports JX1_MGTTX2_N]
set_property IOSTANDARD LVDS [ get_ports JX1_MGTTX2_N]

set_property LOC AJ4 [ get_ports JX1_MGTTX2_P]
set_property IOSTANDARD LVDS [ get_ports JX1_MGTTX2_P]

set_property LOC AK1 [ get_ports JX1_MGTTX3_N]
set_property IOSTANDARD LVDS [ get_ports JX1_MGTTX3_N]

set_property LOC AK2 [ get_ports JX1_MGTTX3_P]
set_property IOSTANDARD LVDS [ get_ports JX1_MGTTX3_P]

set_property LOC AF14 [ get_ports JX1_SE_CLKIN]
set_property IOSTANDARD LVCMOS25 [ get_ports JX1_SE_CLKIN]

set_property LOC AC14 [ get_ports JX1_SE_IO_32]
set_property IOSTANDARD LVCMOS25 [ get_ports JX1_SE_IO_32]

set_property LOC AF17 [ get_ports JX1_SE_IO_0_N]
set_property IOSTANDARD LVDS [ get_ports JX1_SE_IO_0_N]

set_property LOC AF18 [ get_ports JX1_SE_IO_0_P]
set_property IOSTANDARD LVDS [ get_ports JX1_SE_IO_0_P]

set_property LOC AJ18 [ get_ports JX1_SE_IO_2_N]
set_property IOSTANDARD LVDS [ get_ports JX1_SE_IO_2_N]

set_property LOC AH18 [ get_ports JX1_SE_IO_2_P]
set_property IOSTANDARD LVDS [ get_ports JX1_SE_IO_2_P]

set_property LOC AG16 [ get_ports JX1_SE_IO_4_N]
set_property IOSTANDARD LVDS [ get_ports JX1_SE_IO_4_N]

set_property LOC AG17 [ get_ports JX1_SE_IO_4_P]
set_property IOSTANDARD LVDS [ get_ports JX1_SE_IO_4_P]

set_property LOC AF12 [ get_ports JX1_SE_IO_6_N]
set_property IOSTANDARD LVDS [ get_ports JX1_SE_IO_6_N]

set_property LOC AE12 [ get_ports JX1_SE_IO_6_P]
set_property IOSTANDARD LVDS [ get_ports JX1_SE_IO_6_P]

set_property LOC AE15 [ get_ports JX1_SE_IO_8_N]
set_property IOSTANDARD LVDS [ get_ports JX1_SE_IO_8_N]

set_property LOC AE16 [ get_ports JX1_SE_IO_8_P]
set_property IOSTANDARD LVDS [ get_ports JX1_SE_IO_8_P]

set_property LOC AF13 [ get_ports JX1_SE_IO_10_N]
set_property IOSTANDARD LVDS [ get_ports JX1_SE_IO_10_N]

set_property LOC AE13 [ get_ports JX1_SE_IO_10_P]
set_property IOSTANDARD LVDS [ get_ports JX1_SE_IO_10_P]

set_property LOC AE17 [ get_ports JX1_SE_IO_12_N]
set_property IOSTANDARD LVDS [ get_ports JX1_SE_IO_12_N]

set_property LOC AE18 [ get_ports JX1_SE_IO_12_P]
set_property IOSTANDARD LVDS [ get_ports JX1_SE_IO_12_P]

set_property LOC AH12 [ get_ports JX1_SE_IO_14_N]		# DIP_SW1 on the MMP Baseboard 2, Use LVCMOS25
set_property IOSTANDARD LVDS [ get_ports JX1_SE_IO_14_N]

set_property LOC AG12 [ get_ports JX1_SE_IO_14_P]		# DIP_SW0 on the MMP Baseboard 2, Use LVCMOS25
set_property IOSTANDARD LVDS [ get_ports JX1_SE_IO_14_P]

set_property LOC AG15 [ get_ports JX1_SE_IO_16_N]		# DIP_SW3 on the MMP Baseboard 2, Use LVCMOS25
set_property IOSTANDARD LVDS [ get_ports JX1_SE_IO_16_N]

set_property LOC AF15 [ get_ports JX1_SE_IO_16_P]		# DIP_SW2 on the MMP Baseboard 2, Use LVCMOS25
set_property IOSTANDARD LVDS [ get_ports JX1_SE_IO_16_P]

set_property LOC AK16 [ get_ports JX1_SE_IO_18_N]		# DIP_SW5 on the MMP Baseboard 2, Use LVCMOS25
set_property IOSTANDARD LVDS [ get_ports JX1_SE_IO_18_N]

set_property LOC AJ16 [ get_ports JX1_SE_IO_18_P]		# DIP_SW4 on the MMP Baseboard 2, Use LVCMOS25
set_property IOSTANDARD LVDS [ get_ports JX1_SE_IO_18_P]

set_property LOC AK12 [ get_ports JX1_SE_IO_20_N]		# DIP_SW7 on the MMP Baseboard 2, Use LVCMOS25
set_property IOSTANDARD LVDS [ get_ports JX1_SE_IO_20_N]

set_property LOC AK13 [ get_ports JX1_SE_IO_20_P]		# DIP_SW6 on the MMP Baseboard 2, Use LVCMOS25
set_property IOSTANDARD LVDS [ get_ports JX1_SE_IO_20_P]

set_property LOC AH13 [ get_ports JX1_SE_IO_22_N]		# LED1 on the MMP Baseboard 2, Use LVCMOS25
set_property IOSTANDARD LVDS [ get_ports JX1_SE_IO_22_N]

set_property LOC AH14 [ get_ports JX1_SE_IO_22_P]		# LED0 on the MMP Baseboard 2, Use LVCMOS25
set_property IOSTANDARD LVDS [ get_ports JX1_SE_IO_22_P]

set_property LOC AD15 [ get_ports JX1_SE_IO_24_N]		# LED3 on the MMP Baseboard 2, Use LVCMOS25
set_property IOSTANDARD LVDS [ get_ports JX1_SE_IO_24_N]

set_property LOC AD16 [ get_ports JX1_SE_IO_24_P]		# LED2 on the MMP Baseboard 2, Use LVCMOS25
set_property IOSTANDARD LVDS [ get_ports JX1_SE_IO_24_P]

set_property LOC AD13 [ get_ports JX1_SE_IO_26_N]
set_property IOSTANDARD LVDS [ get_ports JX1_SE_IO_26_N]

set_property LOC AD14 [ get_ports JX1_SE_IO_26_P]		# LED4 on the MMP Baseboard 2, Use LVCMOS25
set_property IOSTANDARD LVDS [ get_ports JX1_SE_IO_26_P]

set_property LOC AK15 [ get_ports JX1_SE_IO_28_N]
set_property IOSTANDARD LVDS [ get_ports JX1_SE_IO_28_N]

set_property LOC AJ15 [ get_ports JX1_SE_IO_28_P]
set_property IOSTANDARD LVDS [ get_ports JX1_SE_IO_28_P]

set_property LOC AJ13 [ get_ports JX1_SE_IO_30_N]		# UART_TX on the MMP Baseboard 2, Use LVCMOS25
set_property IOSTANDARD LVDS [ get_ports JX1_SE_IO_30_N]

set_property LOC AJ14 [ get_ports JX1_SE_IO_30_P]		# UART_RX on the MMP Baseboard 2, Use LVCMOS25
set_property IOSTANDARD LVDS [ get_ports JX1_SE_IO_30_P]



##  JX2 Connector - Please modify the I/O standards when using the JX2 signals as single-ended.
set_property LOC N7 [ get_ports JX2_MGTREFCLK_N]
set_property IOSTANDARD LVDS [ get_ports JX2_MGTREFCLK_N]

set_property LOC N8 [ get_ports JX2_MGTREFCLK_P]
set_property IOSTANDARD LVDS [ get_ports JX2_MGTREFCLK_P]

set_property LOC U27 [ get_ports JX2_DIFF_CLKIN_N]
set_property IOSTANDARD LVDS [ get_ports JX2_DIFF_CLKIN_N]

set_property LOC U26 [ get_ports JX2_DIFF_CLKIN_P]
set_property IOSTANDARD LVDS [ get_ports JX2_DIFF_CLKIN_P]

set_property LOC R26 [ get_ports JX2_DIFF_RCLKIN_N]
set_property IOSTANDARD LVDS [ get_ports JX2_DIFF_RCLKIN_N]

set_property LOC R25 [ get_ports JX2_DIFF_RCLKIN_P]
set_property IOSTANDARD LVDS [ get_ports JX2_DIFF_RCLKIN_P]

set_property LOC V29 [ get_ports JX2_DIFF_IO_0_N]
set_property IOSTANDARD LVDS [ get_ports JX2_DIFF_IO_0_N]

set_property LOC V28 [ get_ports JX2_DIFF_IO_0_P]
set_property IOSTANDARD LVDS [ get_ports JX2_DIFF_IO_0_P]

set_property LOC V26 [ get_ports JX2_DIFF_IO_1_N]
set_property IOSTANDARD LVDS [ get_ports JX2_DIFF_IO_1_N]

set_property LOC U25 [ get_ports JX2_DIFF_IO_1_P]
set_property IOSTANDARD LVDS [ get_ports JX2_DIFF_IO_1_P]

set_property LOC W30 [ get_ports JX2_DIFF_IO_2_N]
set_property IOSTANDARD LVDS [ get_ports JX2_DIFF_IO_2_N]

set_property LOC W29 [ get_ports JX2_DIFF_IO_2_P]
set_property IOSTANDARD LVDS [ get_ports JX2_DIFF_IO_2_P]

set_property LOC R30 [ get_ports JX2_DIFF_IO_3_N]
set_property IOSTANDARD LVDS [ get_ports JX2_DIFF_IO_3_N]

set_property LOC P30 [ get_ports JX2_DIFF_IO_3_P]
set_property IOSTANDARD LVDS [ get_ports JX2_DIFF_IO_3_P]

set_property LOC U29 [ get_ports JX2_DIFF_IO_4_N]
set_property IOSTANDARD LVDS [ get_ports JX2_DIFF_IO_4_N]

set_property LOC T29 [ get_ports JX2_DIFF_IO_4_P]
set_property IOSTANDARD LVDS [ get_ports JX2_DIFF_IO_4_P]

set_property LOC W26 [ get_ports JX2_DIFF_IO_5_N]
set_property IOSTANDARD LVDS [ get_ports JX2_DIFF_IO_5_N]

set_property LOC W25 [ get_ports JX2_DIFF_IO_5_P]
set_property IOSTANDARD LVDS [ get_ports JX2_DIFF_IO_5_P]

set_property LOC U30 [ get_ports JX2_DIFF_IO_6_N]
set_property IOSTANDARD LVDS [ get_ports JX2_DIFF_IO_6_N]

set_property LOC T30 [ get_ports JX2_DIFF_IO_6_P]
set_property IOSTANDARD LVDS [ get_ports JX2_DIFF_IO_6_P]

set_property LOC T27 [ get_ports JX2_DIFF_IO_7_N]
set_property IOSTANDARD LVDS [ get_ports JX2_DIFF_IO_7_N]

set_property LOC R27 [ get_ports JX2_DIFF_IO_7_P]
set_property IOSTANDARD LVDS [ get_ports JX2_DIFF_IO_7_P]

set_property LOC N27 [ get_ports JX2_DIFF_IO_8_N]
set_property IOSTANDARD LVDS [ get_ports JX2_DIFF_IO_8_N]

set_property LOC N26 [ get_ports JX2_DIFF_IO_8_P]
set_property IOSTANDARD LVDS [ get_ports JX2_DIFF_IO_8_P]

set_property LOC P26 [ get_ports JX2_DIFF_IO_9_N]
set_property IOSTANDARD LVDS [ get_ports JX2_DIFF_IO_9_N]

set_property LOC P25 [ get_ports JX2_DIFF_IO_9_P]
set_property IOSTANDARD LVDS [ get_ports JX2_DIFF_IO_9_P]

set_property LOC P28 [ get_ports JX2_DIFF_IO_10_N]
set_property IOSTANDARD LVDS [ get_ports JX2_DIFF_IO_10_N]

set_property LOC N28 [ get_ports JX2_DIFF_IO_10_P]
set_property IOSTANDARD LVDS [ get_ports JX2_DIFF_IO_10_P]

set_property LOC T25 [ get_ports JX2_DIFF_IO_11_N]
set_property IOSTANDARD LVDS [ get_ports JX2_DIFF_IO_11_N]

set_property LOC T24 [ get_ports JX2_DIFF_IO_11_P]
set_property IOSTANDARD LVDS [ get_ports JX2_DIFF_IO_11_P]

set_property LOC P29 [ get_ports JX2_DIFF_IO_12_N]
set_property IOSTANDARD LVDS [ get_ports JX2_DIFF_IO_12_N]

set_property LOC N29 [ get_ports JX2_DIFF_IO_12_P]
set_property IOSTANDARD LVDS [ get_ports JX2_DIFF_IO_12_P]

set_property LOC W28 [ get_ports JX2_DIFF_IO_13_N]
set_property IOSTANDARD LVDS [ get_ports JX2_DIFF_IO_13_N]

set_property LOC V27 [ get_ports JX2_DIFF_IO_13_P]
set_property IOSTANDARD LVDS [ get_ports JX2_DIFF_IO_13_P]

set_property LOC U3 [ get_ports JX2_MGTRX0_N]
set_property IOSTANDARD LVDS [ get_ports JX2_MGTRX0_N]

set_property LOC U4 [ get_ports JX2_MGTRX0_P]
set_property IOSTANDARD LVDS [ get_ports JX2_MGTRX0_P]

set_property LOC V5 [ get_ports JX2_MGTRX1_N]
set_property IOSTANDARD LVDS [ get_ports JX2_MGTRX1_N]

set_property LOC V6 [ get_ports JX2_MGTRX1_P]
set_property IOSTANDARD LVDS [ get_ports JX2_MGTRX1_P]

set_property LOC P5 [ get_ports JX2_MGTRX2_N]
set_property IOSTANDARD LVDS [ get_ports JX2_MGTRX2_N]

set_property LOC P6 [ get_ports JX2_MGTRX2_P]
set_property IOSTANDARD LVDS [ get_ports JX2_MGTRX2_P]

set_property LOC T5 [ get_ports JX2_MGTRX3_N]
set_property IOSTANDARD LVDS [ get_ports JX2_MGTRX3_N]

set_property LOC T6 [ get_ports JX2_MGTRX3_P]
set_property IOSTANDARD LVDS [ get_ports JX2_MGTRX3_P]

set_property LOC R3 [ get_ports JX2_MGTTX0_N]
set_property IOSTANDARD LVDS [ get_ports JX2_MGTTX0_N]

set_property LOC R4 [ get_ports JX2_MGTTX0_P]
set_property IOSTANDARD LVDS [ get_ports JX2_MGTTX0_P]

set_property LOC T1 [ get_ports JX2_MGTTX1_N]
set_property IOSTANDARD LVDS [ get_ports JX2_MGTTX1_N]

set_property LOC T2 [ get_ports JX2_MGTTX1_P]
set_property IOSTANDARD LVDS [ get_ports JX2_MGTTX1_P]

set_property LOC N3 [ get_ports JX2_MGTTX2_N]
set_property IOSTANDARD LVDS [ get_ports JX2_MGTTX2_N]

set_property LOC N4 [ get_ports JX2_MGTTX2_P]
set_property IOSTANDARD LVDS [ get_ports JX2_MGTTX2_P]

set_property LOC P1 [ get_ports JX2_MGTTX3_N]
set_property IOSTANDARD LVDS [ get_ports JX2_MGTTX3_N]

set_property LOC P2 [ get_ports JX2_MGTTX3_P]
set_property IOSTANDARD LVDS [ get_ports JX2_MGTTX3_P]

set_property LOC AC18 [ get_ports JX2_SE_CLKIN]
set_property IOSTANDARD LVCMOS25 [ get_ports JX2_SE_CLKIN]

set_property LOC AH28 [ get_ports JX2_SE_IO_32]			# SD_CLK on the MMP Baseboard 2, Use LVCMOS25
set_property IOSTANDARD LVCMOS25 [ get_ports JX2_SE_IO_32]

set_property LOC AA30 [ get_ports JX2_SE_IO_0_N]		# PB1 on the MMP Baseboard 2, Use LVCMOS25
set_property IOSTANDARD LVDS [ get_ports JX2_SE_IO_0_N]

set_property LOC Y30 [ get_ports JX2_SE_IO_0_P]			# PB0 on the MMP Baseboard 2, Use LVCMOS25
set_property IOSTANDARD LVDS [ get_ports JX2_SE_IO_0_P]

set_property LOC AA29 [ get_ports JX2_SE_IO_2_N]		# PB3 on the MMP Baseboard 2, Use LVCMOS25
set_property IOSTANDARD LVDS [ get_ports JX2_SE_IO_2_N]

set_property LOC Y28 [ get_ports JX2_SE_IO_2_P]			# PB2 on the MMP Baseboard 2, Use LVCMOS25
set_property IOSTANDARD LVDS [ get_ports JX2_SE_IO_2_P]

set_property LOC AG27 [ get_ports JX2_SE_IO_4_N]
set_property IOSTANDARD LVDS [ get_ports JX2_SE_IO_4_N]

set_property LOC AG26 [ get_ports JX2_SE_IO_4_P]
set_property IOSTANDARD LVDS [ get_ports JX2_SE_IO_4_P]

set_property LOC AG29 [ get_ports JX2_SE_IO_6_N]
set_property IOSTANDARD LVDS [ get_ports JX2_SE_IO_6_N]

set_property LOC AF29 [ get_ports JX2_SE_IO_6_P]
set_property IOSTANDARD LVDS [ get_ports JX2_SE_IO_6_P]

set_property LOC Y27 [ get_ports JX2_SE_IO_8_N]
set_property IOSTANDARD LVDS [ get_ports JX2_SE_IO_8_N]

set_property LOC Y26 [ get_ports JX2_SE_IO_8_P]
set_property IOSTANDARD LVDS [ get_ports JX2_SE_IO_8_P]

set_property LOC AF25 [ get_ports JX2_SE_IO_10_N]
set_property IOSTANDARD LVDS [ get_ports JX2_SE_IO_10_N]

set_property LOC AE25 [ get_ports JX2_SE_IO_10_P]
set_property IOSTANDARD LVDS [ get_ports JX2_SE_IO_10_P]

set_property LOC AA28 [ get_ports JX2_SE_IO_12_N]
set_property IOSTANDARD LVDS [ get_ports JX2_SE_IO_12_N]

set_property LOC AA27 [ get_ports JX2_SE_IO_12_P]
set_property IOSTANDARD LVDS [ get_ports JX2_SE_IO_12_P]

set_property LOC AD26 [ get_ports JX2_SE_IO_14_N]
set_property IOSTANDARD LVDS [ get_ports JX2_SE_IO_14_N]

set_property LOC AC26 [ get_ports JX2_SE_IO_14_P]
set_property IOSTANDARD LVDS [ get_ports JX2_SE_IO_14_P]

set_property LOC AE30 [ get_ports JX2_SE_IO_16_N]
set_property IOSTANDARD LVDS [ get_ports JX2_SE_IO_16_N]

set_property LOC AD30 [ get_ports JX2_SE_IO_16_P]
set_property IOSTANDARD LVDS [ get_ports JX2_SE_IO_16_P]

set_property LOC AD29 [ get_ports JX2_SE_IO_18_N]
set_property IOSTANDARD LVDS [ get_ports JX2_SE_IO_18_N]

set_property LOC AC29 [ get_ports JX2_SE_IO_18_P]
set_property IOSTANDARD LVDS [ get_ports JX2_SE_IO_18_P]

set_property LOC AG30 [ get_ports JX2_SE_IO_20_N]
set_property IOSTANDARD LVDS [ get_ports JX2_SE_IO_20_N]

set_property LOC AF30 [ get_ports JX2_SE_IO_20_P]
set_property IOSTANDARD LVDS [ get_ports JX2_SE_IO_20_P]

set_property LOC AF28 [ get_ports JX2_SE_IO_22_N]
set_property IOSTANDARD LVDS [ get_ports JX2_SE_IO_22_N]

set_property LOC AE28 [ get_ports JX2_SE_IO_22_P]
set_property IOSTANDARD LVDS [ get_ports JX2_SE_IO_22_P]

set_property LOC AC27 [ get_ports JX2_SE_IO_24_N]
set_property IOSTANDARD LVDS [ get_ports JX2_SE_IO_24_N]

set_property LOC AB27 [ get_ports JX2_SE_IO_24_P]
set_property IOSTANDARD LVDS [ get_ports JX2_SE_IO_24_P]

set_property LOC AF27 [ get_ports JX2_SE_IO_26_N]		# SD_D0 on the MMP Baseboard 2, Use LVCMOS25
set_property IOSTANDARD LVDS [ get_ports JX2_SE_IO_26_N]

set_property LOC AE27 [ get_ports JX2_SE_IO_26_P]
set_property IOSTANDARD LVDS [ get_ports JX2_SE_IO_26_P]

set_property LOC AB30 [ get_ports JX2_SE_IO_28_N]		# SD_D2 on the MMP Baseboard 2, Use LVCMOS25
set_property IOSTANDARD LVDS [ get_ports JX2_SE_IO_28_N]

set_property LOC AB29 [ get_ports JX2_SE_IO_28_P]		# SD_D1 on the MMP Baseboard 2, Use LVCMOS25
set_property IOSTANDARD LVDS [ get_ports JX2_SE_IO_28_P]

set_property LOC AE26 [ get_ports JX2_SE_IO_30_N]		# SD_CMD on the MMP Baseboard 2, Use LVCMOS25
set_property IOSTANDARD LVDS [ get_ports JX2_SE_IO_30_N]

set_property LOC AD25 [ get_ports JX2_SE_IO_30_P]		# SD_D3 on the MMP Baseboard 2, Use LVCMOS25
set_property IOSTANDARD LVDS [ get_ports JX2_SE_IO_30_P]
