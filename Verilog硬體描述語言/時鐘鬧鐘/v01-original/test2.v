module test2 (
    input clk,             // 50MHz 主時脈 (LP-2900 板載)
    input reset,           // 異步重置 (全部歸零)
    input [7:0] sw,        // 8 個按鈕: SW1~SW8
    output reg [7:0] segout,
    output reg [2:0] scanout,
    output reg [11:0] led, // L1~L12 (紅/黃/綠 x 4組)
    output led_com         // LED_COM 腳位 N20
);

//---------------------------------------------------------
// 1. 分頻器：產生 1秒脈波、LED閃爍頻率、長按快調時脈
//---------------------------------------------------------
reg [25:0] cnt_scan;
reg [25:0] cnt_1sec;
reg one_sec_tick;

// 閃爍與快調頻率
wire blink_clk = cnt_scan[24]; // 約 1.5Hz 鬧鐘閃爍
wire auto_inc_clk = cnt_scan[22]; // 約 6Hz：按住按鈕時連續增加的速度

// 取得連續增加的單週期脈波 (避免重複累加)
reg auto_inc_prev;
wire auto_inc_tick = (~auto_inc_prev && auto_inc_clk);

always @(posedge clk or posedge reset) begin
    if (reset) begin
        cnt_scan      <= 26'd0;
        cnt_1sec      <= 26'd0;
        one_sec_tick  <= 1'b0;
        auto_inc_prev <= 1'b0;
    end else begin
        cnt_scan      <= cnt_scan + 1'b1;
        auto_inc_prev <= auto_inc_clk;

        // 50MHz: 計數 50,000,000 次 (49,999,999) 產生精確 1 秒脈波
        if (cnt_1sec >= 26'd49_999_999) begin
            cnt_1sec     <= 26'd0;
            one_sec_tick <= 1'b1;
        end else begin
            cnt_1sec     <= cnt_1sec + 1'b1;
            one_sec_tick <= 1'b0;
        end
    end
end

//---------------------------------------------------------
// 2. 按鍵同步與邊緣檢測 (Active-Low 按壓判定)
//---------------------------------------------------------
reg [7:0] sw_sync;
reg [7:0] sw_prev;
wire [7:0] btn_pressed;
wire [7:0] btn_held;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        sw_sync <= 8'hFF;
        sw_prev <= 8'hFF;
    end else begin
        sw_sync <= sw;
        sw_prev <= sw_sync;
    end
end

assign btn_pressed = sw_prev & ~sw_sync; // 下壓瞬間邊緣 (單次觸發)
assign btn_held    = ~sw_sync;           // 按住中為 1

wire mode_set_time  = btn_held[7]; // 按住 SW8: 調整時間模式
wire mode_set_alarm = btn_held[6]; // 按住 SW7: 調整鬧鐘模式

// 按住按鍵時持續觸發累加信號 (單擊立即加 1，按住則持續每秒加數次)
wire [5:0] inc_trig;
genvar i;
generate
    for (i = 0; i < 6; i = i + 1) begin : gen_trig
        assign inc_trig[i] = btn_pressed[i] || (btn_held[i] && auto_inc_tick);
    end
endgenerate

//---------------------------------------------------------
// 3. 走時暫停 / 啟動旗標 (按 SW8 單擊可切換)
//---------------------------------------------------------
reg clock_running;
always @(posedge clk or posedge reset) begin
    if (reset) begin
        clock_running <= 1'b1; // 預設走時
    end else begin
        // 若在未進入改鬧鐘模式下，短按 SW8 可切換 暫停 / 繼續
        if (!mode_set_alarm && btn_pressed[7]) begin
            clock_running <= ~clock_running;
        end
    end
end

//---------------------------------------------------------
// 4. 時間暫存器與進位控制
//---------------------------------------------------------
reg [3:0] q0, q1, q2, q3, q4, q5;             // 現在時間 HH:MM:SS
reg [3:0] al_q0, al_q1, al_q2, al_q3, al_q4, al_q5; // 鬧鐘時間 HH:MM:SS

always @(posedge clk or posedge reset) begin
    if (reset) begin
        q0 <= 4'd0; q1 <= 4'd0; q2 <= 4'd0;
        q3 <= 4'd0; q4 <= 4'd0; q5 <= 4'd0;
        al_q0 <= 4'd0; al_q1 <= 4'd0; al_q2 <= 4'd0;
        al_q3 <= 4'd0; al_q4 <= 4'd0; al_q5 <= 4'd0;
    end else begin
        // ==========================================
        // 模式 A: 按住 SW8 調整時間 (支援長按持續累加)
        // ==========================================
        if (mode_set_time) begin
            // SW1 (秒個位 0~9)
            if (inc_trig[0]) q0 <= (q0 >= 4'd9) ? 4'd0 : (q0 + 1'b1);
            // SW2 (秒十位 0~5)
            if (inc_trig[1]) q1 <= (q1 >= 4'd5) ? 4'd0 : (q1 + 1'b1);
            // SW3 (分個位 0~9)
            if (inc_trig[2]) q2 <= (q2 >= 4'd9) ? 4'd0 : (q2 + 1'b1);
            // SW4 (分十位 0~5)
            if (inc_trig[3]) q3 <= (q3 >= 4'd5) ? 4'd0 : (q3 + 1'b1);
            // SW5 (時個位)
            if (inc_trig[4]) begin
                if (q5 == 4'd2 && q4 >= 4'd3) q4 <= 4'd0;
                else if (q4 >= 4'd9)           q4 <= 4'd0;
                else                           q4 <= q4 + 1'b1;
            end
            // SW6 (時十位 0~2)
            if (inc_trig[5]) begin
                if (q5 >= 4'd2) begin
                    q5 <= 4'd0;
                end else if (q5 == 4'd1 && q4 > 4'd3) begin
                    q5 <= 4'd2;
                    q4 <= 4'd3;
                end else begin
                    q5 <= q5 + 1'b1;
                end
            end
        end

        // ==========================================
        // 模式 B: 按住 SW7 調整鬧鐘 (支援長按持續累加)
        // ==========================================
        else if (mode_set_alarm) begin
            if (inc_trig[0]) al_q0 <= (al_q0 >= 4'd9) ? 4'd0 : (al_q0 + 1'b1);
            if (inc_trig[1]) al_q1 <= (al_q1 >= 4'd5) ? 4'd0 : (al_q1 + 1'b1);
            if (inc_trig[2]) al_q2 <= (al_q2 >= 4'd9) ? 4'd0 : (al_q2 + 1'b1);
            if (inc_trig[3]) al_q3 <= (al_q3 >= 4'd5) ? 4'd0 : (al_q3 + 1'b1);
            if (inc_trig[4]) begin
                if (al_q5 == 4'd2 && al_q4 >= 4'd3) al_q4 <= 4'd0;
                else if (al_q4 >= 4'd9)              al_q4 <= 4'd0;
                else                                 al_q4 <= al_q4 + 1'b1;
            end
            if (inc_trig[5]) begin
                if (al_q5 >= 4'd2) begin
                    al_q5 <= 4'd0;
                end else if (al_q5 == 4'd1 && al_q4 > 4'd3) begin
                    al_q5 <= 4'd2;
                    al_q4 <= 4'd3;
                end else begin
                    al_q5 <= al_q5 + 1'b1;
                end
            end
        end

        // ==========================================
        // 模式 C: 正常走時 (受 clock_running 啟停控制)
        // ==========================================
        else if (one_sec_tick && clock_running) begin
            if (q0 < 4'd9) begin
                q0 <= q0 + 1'b1;
            end else begin
                q0 <= 4'd0;
                if (q1 < 4'd5) begin
                    q1 <= q1 + 1'b1;
                end else begin
                    q1 <= 4'd0;
                    if (q2 < 4'd9) begin
                        q2 <= q2 + 1'b1;
                    end else begin
                        q2 <= 4'd0;
                        if (q3 < 4'd5) begin
                            q3 <= q3 + 1'b1;
                        end else begin
                            q3 <= 4'd0;
                            if (q5 == 4'd2 && q4 == 4'd3) begin
                                q4 <= 4'd0;
                                q5 <= 4'd0;
                            end else if (q4 < 4'd9) begin
                                q4 <= q4 + 1'b1;
                            end else begin
                                q4 <= 4'd0;
                                q5 <= q5 + 1'b1;
                            end
                        end
                    end
                end
            end
        end
    end
end

//---------------------------------------------------------
// 5. 鬧鐘比對與 12 顆 LED 閃爍輸出
//---------------------------------------------------------
wire alarm_match = ({q5, q4, q3, q2, q1, q0} == {al_q5, al_q4, al_q3, al_q2, al_q1, al_q0});

assign led_com = 1'b0; // 共同端接地 (共陰極)

always @(*) begin
    if (alarm_match && blink_clk) begin
        led = 12'b1111_1111_1111;
    end else begin
        led = 12'b0000_0000_0000;
    end
end

//---------------------------------------------------------
// 6. 七段顯示掃描與顯示控制
//---------------------------------------------------------
reg [3:0] disp_q0, disp_q1, disp_q2, disp_q3, disp_q4, disp_q5;

always @(*) begin
    if (mode_set_alarm) begin
        disp_q0 = al_q0; disp_q1 = al_q1; disp_q2 = al_q2;
        disp_q3 = al_q3; disp_q4 = al_q4; disp_q5 = al_q5;
    end else begin
        disp_q0 = q0;    disp_q1 = q1;    disp_q2 = q2;
        disp_q3 = q3;    disp_q4 = q4;    disp_q5 = q5;
    end
end

always @(*) begin
    scanout = cnt_scan[15:13];
end

reg [3:0] sel;
always @(*) begin
    case (scanout)
        3'b000:  sel = disp_q5; // 時十位
        3'b001:  sel = disp_q4; // 時個位
        3'b010:  sel = disp_q3; // 分十位
        3'b011:  sel = disp_q2; // 分個位
        3'b100:  sel = disp_q1; // 秒十位
        3'b101:  sel = disp_q0; // 秒個位
        default: sel = 4'h0;
    endcase
end

// 七段顯示解碼器 (共陰極：高電位點亮)
always @(*) begin
    case (sel)
        4'h0:    segout = 8'b00111111;
        4'h1:    segout = 8'b00000110;
        4'h2:    segout = 8'b01011011;
        4'h3:    segout = 8'b01001111;
        4'h4:    segout = 8'b01100110;
        4'h5:    segout = 8'b01101101;
        4'h6:    segout = 8'b01111101;
        4'h7:    segout = 8'b00000111;
        4'h8:    segout = 8'b01111111;
        4'h9:    segout = 8'b01100111;
        default: segout = 8'b00000000;
    endcase
end

endmodule
