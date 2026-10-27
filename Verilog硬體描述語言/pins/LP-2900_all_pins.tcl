# test2 腳位設定 (LP-2900)
# 用法：Quartus 開啟專案後 → Tools → Tcl Scripts… → 選這個檔 → Run

# 時脈 W16 (已確認) / 重置 N16 (尚未對照手冊)
set_location_assignment PIN_W16 -to clk
set_location_assignment PIN_N16 -to reset

# 按鍵 SW1~SW8 (Push Button，依手冊)
set_location_assignment PIN_AA15 -to sw[0]
set_location_assignment PIN_AA14 -to sw[1]
set_location_assignment PIN_AB18 -to sw[2]
set_location_assignment PIN_AA18 -to sw[3]
set_location_assignment PIN_AB17 -to sw[4]
set_location_assignment PIN_AA17 -to sw[5]
set_location_assignment PIN_AB20 -to sw[6]
set_location_assignment PIN_AA20 -to sw[7]

# 七段顯示器段碼 A~DP (共陰極，HI 點亮，依手冊)
set_location_assignment PIN_AB7 -to segout[0]
set_location_assignment PIN_AA7 -to segout[1]
set_location_assignment PIN_AB6 -to segout[2]
set_location_assignment PIN_AB5 -to segout[3]
set_location_assignment PIN_AA9 -to segout[4]
set_location_assignment PIN_Y9  -to segout[5]
set_location_assignment PIN_AB8 -to segout[6]
set_location_assignment PIN_AA8 -to segout[7]

# 七段顯示器掃描 74138 DE1~DE3 (依手冊)
set_location_assignment PIN_AA12 -to scanout[0]
set_location_assignment PIN_AB11 -to scanout[1]
set_location_assignment PIN_AB10 -to scanout[2]

# LED L1~L12 (陽極，HI 點亮，依手冊)
set_location_assignment PIN_E2  -to led[0]
set_location_assignment PIN_D3  -to led[1]
set_location_assignment PIN_C2  -to led[2]
set_location_assignment PIN_C1  -to led[3]
set_location_assignment PIN_L2  -to led[4]
set_location_assignment PIN_L1  -to led[5]
set_location_assignment PIN_G2  -to led[6]
set_location_assignment PIN_G1  -to led[7]
set_location_assignment PIN_U2  -to led[8]
set_location_assignment PIN_N1  -to led[9]
set_location_assignment PIN_AA2 -to led[10]
set_location_assignment PIN_AA1 -to led[11]

# LED_COM
set_location_assignment PIN_N20 -to led_com

# 蜂鳴器
set_location_assignment PIN_AB15 -to buzzer
