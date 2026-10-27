# Verilog 硬體描述語言實驗（LP-2900）

每個版本一個資料夾，裡面放當時的 Verilog 原始檔。找東西時先看下面的總表。

- 實驗平台：LP-2900 CPLD 邏輯設計實驗平台（Altera Cyclone 晶片板）
- 開發工具：Quartus II
- 語言：Verilog
- 腳位設定檔：[pins/LP-2900_all_pins.tcl](pins/LP-2900_all_pins.tcl)（Quartus → Tools → Tcl Scripts → Run）

## 一、版本索引

### 時鐘鬧鐘（`時鐘鬧鐘/`）

六顆七段顯示 HH:MM:SS。按住 SW8 改時間、按住 SW7 改鬧鐘，再按住 SW1～SW6 調對應的那一位。

| 版本 | 資料夾 | 做了什麼 | 測試狀態 |
|---|---|---|---|
| v01 | [v01-original](時鐘鬧鐘/v01-original/test2.v) | 原始版：按鍵當 Active-Low、短按 SW8 切換暫停。另附當時的需求與討論 | 按鍵極性錯，沒按的位數一直跳 |
| v02 | [v02-button-polarity-params](時鐘鬧鐘/v02-button-polarity-params/test2.v) | 修正按鍵極性；加 `CLK_HZ`、`ADJ_HZ` 參數；設定中時間凍結 | 走時太慢（時脈不是 50MHz） |
| v03 | [v03-compile-error-pins-in-code](時鐘鬧鐘/v03-compile-error-pins-in-code/test2.v) | ⚠ 錯誤示範：把 `set_location_assignment` 貼進程式 | 編譯失敗（4 errors） |
| v04 | [v04-alarm-led-30s](時鐘鬧鐘/v04-alarm-led-30s/test2.v) | 整合版：鬧鐘時間到 LED 閃 30 秒，按任意鍵停止 | 腳位當時未對照手冊，LED 不亮 |
| v05 | [v05-w16-clock-10mhz](時鐘鬧鐘/v05-w16-clock-10mhz/test2.v) | 時脈改 W16、`CLK_HZ = 10MHz`、重置改 Active-Low | 已燒錄，時間正確 |
| v06 | [v06-alarm-led-fx-buzzer](時鐘鬧鐘/v06-alarm-led-fx-buzzer/test2.v) | **最新版**：鬧鐘 LED 六種特效 + 蜂鳴器音樂，`VOL` 調音量 | 未回報 |

### 七段跑馬燈（`七段跑馬燈/`）

| 版本 | 資料夾 | 做了什麼 | 測試狀態 |
|---|---|---|---|
| v01 | [v01-rom-frame-table](七段跑馬燈/v01-rom-frame-table/test3.v) | 畫格表寫法：342 格動畫存成 46 位元 ROM，只有七段 | 未回報 |
| v02 | [v02-row-bits-led-sound-buttons](七段跑馬燈/v02-row-bits-led-sound-buttons/test2.v) | 改成「一排一排 `6'b000001`」寫法；16 個場景 + LED + 15 種音效 + 8 顆按鍵 | 已燒錄 |
| v03 | [v03-simple-patterns](七段跑馬燈/v03-simple-patterns/test3.v) | 簡化版：拿掉按鍵、聲音、文字，只留 14 種花樣 | 未回報 |
| v04 | [v04-buzzer-volume](七段跑馬燈/v04-buzzer-volume/test2.v) | 同 v02，加蜂鳴器音量 `VOL`（窄脈衝降音量） | 已燒錄，`VOL = 1` |
| v05 | [v05-22-effects-no-text](七段跑馬燈/v05-22-effects-no-text/test2.v) | 拿掉文字，特效增加到 22 種（新增呼吸、水位、閃電、雙球對撞等） | 未回報 |
| v06 | [v06-24-scenes-with-text](七段跑馬燈/v06-24-scenes-with-text/test2.v) | **最新版**：22 種特效 + 加回 `3 2 1 GO`、`HELLO-FPGA 2026`、`End` | 已燒錄，`LED_COM = 1` |

跑馬燈 v02 之後的按鍵：

| 按鍵 | 功能 | 按鍵 | 功能 |
|---|---|---|---|
| SW1 | 下一個場景 | SW5 | 暫停／繼續 |
| SW2 | 上一個場景 | SW6 | 靜音 |
| SW3 | 加速 | SW7 | 左右鏡像 |
| SW4 | 減速 | SW8 | 按住 4 倍速 |

## 二、LP-2900 腳位（已依手冊確認）

| 訊號 | 腳位 | 備註 |
|---|---|---|
| clk | W16 | 實測約 10MHz，程式 `CLK_HZ = 10_000_000` |
| reset | N16 | Active-Low（程式用 `negedge reset`） |
| sw[0]～sw[7]（SW1～SW8） | AA15, AA14, AB18, AA18, AB17, AA17, AB20, AA20 | Push Button，按下 = 1 |
| segout[0]～segout[7]（A～DP） | AB7, AA7, AB6, AB5, AA9, Y9, AB8, AA8 | 共陰極，HI 點亮 |
| scanout[0]～scanout[2]（DE1～DE3） | AA12, AB11, AB10 | 接 74138，000 = 最左顆 |
| led[0]～led[11]（L1～L12） | E2, D3, C2, C1, L2, L1, G2, G1, U2, N1, AA2, AA1 | 紅黃綠 ×4，陽極 HI 點亮 |
| led_com | N20 | 要給 **1** 才會亮 |
| buzzer | AB15 | |

## 三、踩過的坑

- **按鍵極性接反**：沒按的位數全部在跳、按下的反而不動 → 改 `BTN_ACTIVE_LOW`／`BTN_LOW`。
- **時間跑太慢**：`clk` 原本接錯腳，改 W16 後再依實測調 `CLK_HZ`。
- **只有最左邊七段亮**：一直處在重置狀態 → 重置極性反了。
- **LED 沒亮**：`LED_COM` 要給 1。
- **腳位不能寫在 `.v` 裡**：`set_location_assignment` 要放 Pin Planner 或 `.qsf`／`.tcl`。
- **舊腳位整組錯**：按鍵、七段、LED 原本都不是手冊上的腳位，換專案時要重新核對。
- **蜂鳴器太大聲**：縮短每個週期通電的時間（`VOL` 參數），音高不變。
