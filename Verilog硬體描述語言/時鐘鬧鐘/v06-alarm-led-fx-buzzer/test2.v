module test2 #(
    parameter BTN_ACTIVE_LOW = 0,            // 0: 按下=1；行為相反就改 1
    parameter CLK_HZ         = 10_000_000,   // W16 時脈頻率
    parameter RST_ACTIVE_LOW = 1,            // 只有最左邊亮/時間不走 就改成 0
    parameter ADJ_HZ         = 10,           // 調整時每秒加幾次
    parameter RING_SEC       = 30,           // 鬧鐘閃幾秒
    parameter LED_COM_LEVEL  = 1'b0,         // LED 不亮就改成 1'b1
    parameter BUZZ_IDLE      = 1'b0,         // 不響時蜂鳴器一直叫就改成 1'b1
    parameter VOL            = 2             // 音量 1(最小) ~ 8(最大)
)(
    input clk,
    input reset,                 // 重置鍵
    input [7:0] sw,              // SW1~SW8
    output reg [7:0] segout,
    output reg [2:0] scanout,
    output reg [11:0] led,       // L1~L12
    output led_com,              // N20
    output buzzer                // AB15
);

//---------------------------------------------------------
// 常數
//---------------------------------------------------------
wire rst = RST_ACTIVE_LOW ? ~reset : reset;   // 內部統一 1 = 重置

localparam [7:0]  SW_IDLE   = BTN_ACTIVE_LOW ? 8'hFF : 8'h00;
localparam [25:0] SEC_MAX   = CLK_HZ - 1;
localparam [25:0] ADJ_MAX   = CLK_HZ / ADJ_HZ - 1;
localparam [25:0] BLINK_MAX = CLK_HZ / 4 - 1;   // 約 2Hz 閃爍
localparam [5:0]  RING_CNT  = RING_SEC;
localparam [25:0] FX_MAX    = CLK_HZ / 12 - 1;  // LED 特效每秒 12 步
localparam [25:0] MEL_MAX   = CLK_HZ / 16 - 1;  // 音樂每拍 1/16 秒
localparam [5:0]  MEL_N     = 46;               // 音樂表長度

//---------------------------------------------------------
// 1. 按鍵同步與極性
//---------------------------------------------------------
reg [7:0] sw_s1, sw_s2;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        sw_s1 <= SW_IDLE;
        sw_s2 <= SW_IDLE;
    end else begin
        sw_s1 <= sw;
        sw_s2 <= sw_s1;
    end
end

wire [7:0] btn_held       = BTN_ACTIVE_LOW ? ~sw_s2 : sw_s2; // 按住 = 1
wire       mode_set_time  = btn_held[7];                     // 按住 SW8：改時間
wire       mode_set_alarm = btn_held[6] & ~btn_held[7];      // 按住 SW7：改鬧鐘
wire       is_setting     = btn_held[7] | btn_held[6];       // 設定中，時間凍結
wire [5:0] dig_held       = btn_held[5:0];                   // SW1~SW6
wire       any_dig_held   = |dig_held;

//---------------------------------------------------------
// 2. 分頻器
//---------------------------------------------------------
reg [25:0] cnt_scan, cnt_1sec, cnt_adj, cnt_blink;
reg one_sec_tick, adj_tick, blink;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        cnt_scan     <= 26'd0;
        cnt_1sec     <= 26'd0;
        cnt_adj      <= 26'd0;
        cnt_blink    <= 26'd0;
        one_sec_tick <= 1'b0;
        adj_tick     <= 1'b0;
        blink        <= 1'b0;
    end else begin
        cnt_scan <= cnt_scan + 1'b1;

        // 走時 (設定中凍結)
        if (is_setting) begin
            cnt_1sec     <= 26'd0;
            one_sec_tick <= 1'b0;
        end else if (cnt_1sec >= SEC_MAX) begin
            cnt_1sec     <= 26'd0;
            one_sec_tick <= 1'b1;
        end else begin
            cnt_1sec     <= cnt_1sec + 1'b1;
            one_sec_tick <= 1'b0;
        end

        // 調整步進 (按住 SW1~SW6 才計數，放開歸零)
        if (!is_setting || !any_dig_held) begin
            cnt_adj  <= 26'd0;
            adj_tick <= 1'b0;
        end else if (cnt_adj >= ADJ_MAX) begin
            cnt_adj  <= 26'd0;
            adj_tick <= 1'b1;
        end else begin
            cnt_adj  <= cnt_adj + 1'b1;
            adj_tick <= 1'b0;
        end

        // LED 閃爍
        if (cnt_blink >= BLINK_MAX) begin
            cnt_blink <= 26'd0;
            blink     <= ~blink;
        end else begin
            cnt_blink <= cnt_blink + 1'b1;
        end
    end
end

wire [5:0] inc_trig = dig_held & {6{adj_tick}};

//---------------------------------------------------------
// 3. 時間 / 鬧鐘暫存器
//    q0 秒個 q1 秒十 q2 分個 q3 分十 q4 時個 q5 時十
//---------------------------------------------------------
reg [3:0] q0, q1, q2, q3, q4, q5;
reg [3:0] al_q0, al_q1, al_q2, al_q3, al_q4, al_q5;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        q0 <= 4'd0; q1 <= 4'd0; q2 <= 4'd0; q3 <= 4'd0; q4 <= 4'd0; q5 <= 4'd0;
        al_q0 <= 4'd0; al_q1 <= 4'd0; al_q2 <= 4'd0;
        al_q3 <= 4'd0; al_q4 <= 4'd0; al_q5 <= 4'd0;
    end else if (mode_set_time) begin
        // 按住 SW8：只有被按住的那一位會增加
        if (inc_trig[5]) begin                                   // SW6 時十位
            if (q5 >= 4'd2)                   q5 <= 4'd0;
            else if (q5 == 4'd1 && q4 > 4'd3) begin q5 <= 4'd2; q4 <= 4'd3; end
            else                              q5 <= q5 + 1'b1;
        end
        else if (inc_trig[4]) begin                              // SW5 時個位
            if (q5 == 4'd2 && q4 >= 4'd3)     q4 <= 4'd0;
            else if (q4 >= 4'd9)              q4 <= 4'd0;
            else                              q4 <= q4 + 1'b1;
        end
        else if (inc_trig[3]) q3 <= (q3 >= 4'd5) ? 4'd0 : q3 + 1'b1;  // SW4 分十位
        else if (inc_trig[2]) q2 <= (q2 >= 4'd9) ? 4'd0 : q2 + 1'b1;  // SW3 分個位
        else if (inc_trig[1]) q1 <= (q1 >= 4'd5) ? 4'd0 : q1 + 1'b1;  // SW2 秒十位
        else if (inc_trig[0]) q0 <= (q0 >= 4'd9) ? 4'd0 : q0 + 1'b1;  // SW1 秒個位
    end else if (mode_set_alarm) begin
        // 按住 SW7：改鬧鐘
        if (inc_trig[5]) begin
            if (al_q5 >= 4'd2)                      al_q5 <= 4'd0;
            else if (al_q5 == 4'd1 && al_q4 > 4'd3) begin al_q5 <= 4'd2; al_q4 <= 4'd3; end
            else                                    al_q5 <= al_q5 + 1'b1;
        end
        else if (inc_trig[4]) begin
            if (al_q5 == 4'd2 && al_q4 >= 4'd3)     al_q4 <= 4'd0;
            else if (al_q4 >= 4'd9)                 al_q4 <= 4'd0;
            else                                    al_q4 <= al_q4 + 1'b1;
        end
        else if (inc_trig[3]) al_q3 <= (al_q3 >= 4'd5) ? 4'd0 : al_q3 + 1'b1;
        else if (inc_trig[2]) al_q2 <= (al_q2 >= 4'd9) ? 4'd0 : al_q2 + 1'b1;
        else if (inc_trig[1]) al_q1 <= (al_q1 >= 4'd5) ? 4'd0 : al_q1 + 1'b1;
        else if (inc_trig[0]) al_q0 <= (al_q0 >= 4'd9) ? 4'd0 : al_q0 + 1'b1;
    end else if (one_sec_tick) begin
        // 正常走時
        if (q0 < 4'd9) q0 <= q0 + 1'b1;
        else begin
            q0 <= 4'd0;
            if (q1 < 4'd5) q1 <= q1 + 1'b1;
            else begin
                q1 <= 4'd0;
                if (q2 < 4'd9) q2 <= q2 + 1'b1;
                else begin
                    q2 <= 4'd0;
                    if (q3 < 4'd5) q3 <= q3 + 1'b1;
                    else begin
                        q3 <= 4'd0;
                        if (q5 == 4'd2 && q4 == 4'd3) begin q4 <= 4'd0; q5 <= 4'd0; end
                        else if (q4 < 4'd9) q4 <= q4 + 1'b1;
                        else begin q4 <= 4'd0; q5 <= q5 + 1'b1; end
                    end
                end
            end
        end
    end
end

//---------------------------------------------------------
// 4. 鬧鐘：時間到 LED 特效 + 蜂鳴器音樂 RING_SEC 秒，按任意鍵停止
//---------------------------------------------------------
wire alarm_match = ({q5,q4,q3,q2,q1,q0} == {al_q5,al_q4,al_q3,al_q2,al_q1,al_q0});

reg       alarm_match_d;
reg       alarm_on;
reg       alarm_start;
reg [5:0] ring_cnt;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        alarm_match_d <= 1'b1;   // 避免開機 00:00:00 就響
        alarm_on      <= 1'b0;
        alarm_start   <= 1'b0;
        ring_cnt      <= 6'd0;
    end else begin
        alarm_match_d <= alarm_match;
        alarm_start   <= 1'b0;
        if (|btn_held) begin                               // 按任何鍵停止
            alarm_on <= 1'b0;
            ring_cnt <= 6'd0;
        end else if (alarm_match && !alarm_match_d) begin  // 走到鬧鐘時間
            alarm_on    <= 1'b1;
            alarm_start <= 1'b1;
            ring_cnt    <= RING_CNT;
        end else if (alarm_on && one_sec_tick) begin       // 每秒倒數
            if (ring_cnt <= 6'd1) alarm_on <= 1'b0;
            ring_cnt <= ring_cnt - 1'b1;
        end
    end
end

//---------------------------------------------------------
// 4-1. 音樂表 {音符, 拍數}
//   音符: 0 休止 1 C5 2 D5 3 E5 4 F5 5 G5 6 A5 7 B5 8 C6 9 E6 10 G6 11 C7
//   拍數: 1 拍 = 1/16 秒
//---------------------------------------------------------
function [7:0] mel;
    input [5:0] k;
    begin
        case (k)
            // 號角開場
            6'd0:  mel = {4'd5,  4'd2};
            6'd1:  mel = {4'd8,  4'd2};
            6'd2:  mel = {4'd9,  4'd2};
            6'd3:  mel = {4'd10, 4'd6};
            6'd4:  mel = {4'd0,  4'd2};
            6'd5:  mel = {4'd9,  4'd2};
            6'd6:  mel = {4'd10, 4'd8};
            6'd7:  mel = {4'd0,  4'd4};
            // 警笛 高低交替
            6'd8:  mel = {4'd6,  4'd3};
            6'd9:  mel = {4'd9,  4'd3};
            6'd10: mel = {4'd6,  4'd3};
            6'd11: mel = {4'd9,  4'd3};
            6'd12: mel = {4'd6,  4'd3};
            6'd13: mel = {4'd9,  4'd3};
            6'd14: mel = {4'd6,  4'd3};
            6'd15: mel = {4'd9,  4'd3};
            // 往上滑音
            6'd16: mel = {4'd1,  4'd1};
            6'd17: mel = {4'd2,  4'd1};
            6'd18: mel = {4'd3,  4'd1};
            6'd19: mel = {4'd4,  4'd1};
            6'd20: mel = {4'd5,  4'd1};
            6'd21: mel = {4'd6,  4'd1};
            6'd22: mel = {4'd7,  4'd1};
            6'd23: mel = {4'd8,  4'd1};
            6'd24: mel = {4'd9,  4'd1};
            6'd25: mel = {4'd10, 4'd1};
            6'd26: mel = {4'd11, 4'd3};
            6'd27: mel = {4'd0,  4'd3};
            // 往下滑音
            6'd28: mel = {4'd11, 4'd1};
            6'd29: mel = {4'd10, 4'd1};
            6'd30: mel = {4'd9,  4'd1};
            6'd31: mel = {4'd8,  4'd1};
            6'd32: mel = {4'd7,  4'd1};
            6'd33: mel = {4'd6,  4'd1};
            6'd34: mel = {4'd5,  4'd1};
            6'd35: mel = {4'd4,  4'd1};
            6'd36: mel = {4'd3,  4'd1};
            6'd37: mel = {4'd2,  4'd1};
            6'd38: mel = {4'd1,  4'd3};
            6'd39: mel = {4'd0,  4'd3};
            // 嗶嗶嗶
            6'd40: mel = {4'd11, 4'd1};
            6'd41: mel = {4'd0,  4'd1};
            6'd42: mel = {4'd11, 4'd1};
            6'd43: mel = {4'd0,  4'd1};
            6'd44: mel = {4'd11, 4'd1};
            6'd45: mel = {4'd0,  4'd6};
            default: mel = {4'd0, 4'd1};
        endcase
    end
endfunction

// 音符 -> 方波半週期 (clk 數)
function [19:0] half;
    input [3:0] n;
    begin
        case (n)
            4'd1:  half = CLK_HZ / (2 * 523);
            4'd2:  half = CLK_HZ / (2 * 587);
            4'd3:  half = CLK_HZ / (2 * 659);
            4'd4:  half = CLK_HZ / (2 * 698);
            4'd5:  half = CLK_HZ / (2 * 784);
            4'd6:  half = CLK_HZ / (2 * 880);
            4'd7:  half = CLK_HZ / (2 * 988);
            4'd8:  half = CLK_HZ / (2 * 1047);
            4'd9:  half = CLK_HZ / (2 * 1319);
            4'd10: half = CLK_HZ / (2 * 1568);
            4'd11: half = CLK_HZ / (2 * 2093);
            default: half = 20'd0;
        endcase
    end
endfunction

//---------------------------------------------------------
// 4-2. 音樂播放器 + 蜂鳴器方波
//---------------------------------------------------------
reg [25:0] cnt_mel;
reg [5:0]  mel_k;
reg [3:0]  mel_left;
reg [19:0] tone_cnt;
reg        buzz;

wire [3:0]  cur_note = mel(mel_k) >> 4;
wire [19:0] tone_max = half(cur_note);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        cnt_mel  <= 26'd0;
        mel_k    <= 6'd0;
        mel_left <= 4'd0;
        tone_cnt <= 20'd0;
        buzz     <= 1'b0;
    end else if (alarm_start) begin
        cnt_mel  <= 26'd0;
        mel_k    <= 6'd0;
        mel_left <= mel(6'd0);
        tone_cnt <= 20'd0;
        buzz     <= 1'b0;
    end else if (!alarm_on) begin
        tone_cnt <= 20'd0;
        buzz     <= 1'b0;
    end else begin
        // 換音符
        if (cnt_mel >= MEL_MAX) begin
            cnt_mel <= 26'd0;
            if (mel_left <= 4'd1) begin
                mel_k    <= (mel_k == MEL_N - 1) ? 6'd0 : mel_k + 1'b1;
                mel_left <= mel((mel_k == MEL_N - 1) ? 6'd0 : mel_k + 1'b1);
            end else begin
                mel_left <= mel_left - 1'b1;
            end
        end else begin
            cnt_mel <= cnt_mel + 1'b1;
        end

        // 產生音高
        if (cur_note == 4'd0) begin
            tone_cnt <= 20'd0;
            buzz     <= 1'b0;
        end else if (tone_cnt >= tone_max - 1'b1) begin
            tone_cnt <= 20'd0;
            buzz     <= ~buzz;
        end else begin
            tone_cnt <= tone_cnt + 1'b1;
        end
    end
end

// 音量：高電位只維持半週期的 VOL/8，脈衝越窄越小聲
wire [23:0] on_len = (tone_max * VOL) >> 3;
wire        buzz_q = buzz & (tone_cnt < on_len);

assign buzzer = buzz_q ^ BUZZ_IDLE;

//---------------------------------------------------------
// 4-3. LED 特效：6 種花樣，每 4 秒換一種
//   led[0]~led[11] = L1~L12 (紅黃綠 x 4 組)
//---------------------------------------------------------
reg [25:0] cnt_fx;
reg [7:0]  fx_step;
reg [2:0]  fx_mode;
reg [11:0] lfsr;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        cnt_fx  <= 26'd0;
        fx_step <= 8'd0;
        fx_mode <= 3'd0;
        lfsr    <= 12'hACE;
    end else if (alarm_start) begin
        cnt_fx  <= 26'd0;
        fx_step <= 8'd0;
        fx_mode <= 3'd0;
    end else if (alarm_on) begin
        if (cnt_fx >= FX_MAX) begin
            cnt_fx <= 26'd0;
            lfsr   <= {lfsr[10:0], lfsr[11] ^ lfsr[10] ^ lfsr[9] ^ lfsr[3]};
            if (fx_step >= 8'd47) begin
                fx_step <= 8'd0;
                fx_mode <= (fx_mode >= 3'd5) ? 3'd0 : fx_mode + 1'b1;
            end else begin
                fx_step <= fx_step + 1'b1;
            end
        end else begin
            cnt_fx <= cnt_fx + 1'b1;
        end
    end
end

assign led_com = LED_COM_LEVEL;

wire [7:0]  k22  = fx_step % 22;
wire [3:0]  kpos = (k22 < 8'd12) ? k22[3:0] : (8'd22 - k22);
wire [13:0] kr   = 14'b111 << kpos;
wire [7:0]  k3   = fx_step % 3;
wire [7:0]  k12  = fx_step % 12;
wire [3:0]  vlen = (cur_note == 4'd0) ? 4'd0 : cur_note + 4'd1;

integer j;
reg [3:0] dist;

always @(*) begin
    led = 12'h000;
    if (alarm_on) begin
        case (fx_mode)
            // 0. 霹靂車：三顆燈左右來回掃
            3'd0: led = kr[12:1];

            // 1. 紅綠燈波浪：紅→黃→綠 依序推進，每組錯開
            3'd1: for (j = 0; j < 4; j = j + 1)
                      led[j*3 +: 3] = 3'b001 << ((k3 + j) % 3);

            // 2. 音樂頻譜：燈條長度跟著蜂鳴器音高跳動
            3'd2: led = 12'hFFF >> (4'd12 - vlen);

            // 3. 中心爆炸：從中間往兩邊擴散再縮回
            3'd3: for (j = 0; j < 12; j = j + 1) begin
                      dist = (j <= 5) ? (5 - j) : (j - 6);
                      led[j] = (k12 < 8'd6) ? (dist <= k12) : (dist > k12 - 8'd6);
                  end

            // 4. 隨機星光
            3'd4: led = lfsr;

            // 5. 雙組交替爆閃
            default: led = fx_step[1] ? 12'h1C7 : 12'hE38;
        endcase
    end
end

//---------------------------------------------------------
// 5. 七段顯示 (按住 SW7 時顯示鬧鐘)
//---------------------------------------------------------
wire [3:0] d0 = mode_set_alarm ? al_q0 : q0;
wire [3:0] d1 = mode_set_alarm ? al_q1 : q1;
wire [3:0] d2 = mode_set_alarm ? al_q2 : q2;
wire [3:0] d3 = mode_set_alarm ? al_q3 : q3;
wire [3:0] d4 = mode_set_alarm ? al_q4 : q4;
wire [3:0] d5 = mode_set_alarm ? al_q5 : q5;

always @(*) scanout = cnt_scan[16:14];   // 50MHz 下每位約 0.33ms

reg [3:0] sel;
always @(*) begin
    case (scanout)
        3'd0: sel = d5;   // 時十位
        3'd1: sel = d4;   // 時個位
        3'd2: sel = d3;   // 分十位
        3'd3: sel = d2;   // 分個位
        3'd4: sel = d1;   // 秒十位
        3'd5: sel = d0;   // 秒個位
        default: sel = 4'hF;  // 不顯示
    endcase
end

// 七段解碼 (共陰極：1 點亮)
always @(*) begin
    case (sel)
        4'h0: segout = 8'b00111111;
        4'h1: segout = 8'b00000110;
        4'h2: segout = 8'b01011011;
        4'h3: segout = 8'b01001111;
        4'h4: segout = 8'b01100110;
        4'h5: segout = 8'b01101101;
        4'h6: segout = 8'b01111101;
        4'h7: segout = 8'b00000111;
        4'h8: segout = 8'b01111111;
        4'h9: segout = 8'b01100111;
        default: segout = 8'b00000000;
    endcase
end

endmodule