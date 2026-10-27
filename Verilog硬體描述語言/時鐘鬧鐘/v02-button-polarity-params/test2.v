module test2 #(
    parameter BTN_ACTIVE_LOW = 0,
    parameter CLK_HZ = 50_000_000,  // ← 改成你量到的實際時脈
    parameter ADJ_HZ = 10
)(
    input clk,               // 50MHz
    input reset,             // 高電位重置
    input [7:0] sw,          // SW1~SW8
    output reg [7:0] segout,
    output reg [2:0] scanout,
    output reg [11:0] led,
    output led_com
);

//---------------------------------------------------------
// 1. 按鍵同步 (兩級正反器) 與極性處理
//---------------------------------------------------------
localparam [7:0] SW_IDLE = BTN_ACTIVE_LOW ? 8'hFF : 8'h00;

reg [7:0] sw_s1, sw_s2;
always @(posedge clk or posedge reset) begin
    if (reset) begin
        sw_s1 <= SW_IDLE;
        sw_s2 <= SW_IDLE;
    end else begin
        sw_s1 <= sw;
        sw_s2 <= sw_s1;
    end
end

wire [7:0] btn_held = BTN_ACTIVE_LOW ? ~sw_s2 : sw_s2; // 按住 = 1

wire mode_set_time  = btn_held[7];                  // 按住 SW8：改時間
wire mode_set_alarm = btn_held[6] & ~btn_held[7];   // 按住 SW7：改鬧鐘 (SW8 優先)
wire is_setting     = btn_held[7] | btn_held[6];    // 設定中，時間凍結

wire [5:0] dig_held = btn_held[5:0];                // SW1~SW6
wire any_dig_held   = |dig_held;
localparam [25:0] SEC_MAX = CLK_HZ - 1;
localparam [25:0] ADJ_MAX = CLK_HZ / ADJ_HZ - 1;
//---------------------------------------------------------
// 2. 分頻器
//---------------------------------------------------------
reg [25:0] cnt_scan;
reg [25:0] cnt_1sec;     // 走時用
reg [25:0] cnt_adj;      // 調整用 (從按下 SW1~SW6 那一刻開始算)
reg one_sec_tick;
reg adj_tick;

wire blink_clk = cnt_scan[24];

always @(posedge clk or posedge reset) begin
    if (reset) begin
        cnt_scan     <= 26'd0;
        cnt_1sec     <= 26'd0;
        cnt_adj      <= 26'd0;
        one_sec_tick <= 1'b0;
        adj_tick     <= 1'b0;
    end else begin
        cnt_scan <= cnt_scan + 1'b1;

        // 走時：設定中完全凍結
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

        // 調整：只有在設定模式且按住 SW1~SW6 時才計數，每滿 1 秒 +1，放開立刻歸零
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
    end
end

wire [5:0] inc_trig = dig_held & {6{adj_tick}};

//---------------------------------------------------------
// 3. 時間 / 鬧鐘暫存器
//---------------------------------------------------------
reg [3:0] q0, q1, q2, q3, q4, q5;                    // 秒個 秒十 分個 分十 時個 時十
reg [3:0] al_q0, al_q1, al_q2, al_q3, al_q4, al_q5;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        q0 <= 0; q1 <= 0; q2 <= 0; q3 <= 0; q4 <= 0; q5 <= 0;
        al_q0 <= 0; al_q1 <= 0; al_q2 <= 0; al_q3 <= 0; al_q4 <= 0; al_q5 <= 0;
    end else if (mode_set_time) begin
        // 按住 SW8：只有被按住的那一位每秒 +1，其餘不動
        if (inc_trig[5]) begin                       // SW6 時十位
            if (q5 >= 4'd2)                   q5 <= 4'd0;
            else if (q5 == 4'd1 && q4 > 4'd3) begin q5 <= 4'd2; q4 <= 4'd3; end
            else                              q5 <= q5 + 1'b1;
        end
        else if (inc_trig[4]) begin                  // SW5 時個位
            if (q5 == 4'd2 && q4 >= 4'd3)     q4 <= 4'd0;
            else if (q4 >= 4'd9)              q4 <= 4'd0;
            else                              q4 <= q4 + 1'b1;
        end
        else if (inc_trig[3]) q3 <= (q3 >= 4'd5) ? 4'd0 : q3 + 1'b1; // SW4 分十位
        else if (inc_trig[2]) q2 <= (q2 >= 4'd9) ? 4'd0 : q2 + 1'b1; // SW3 分個位
        else if (inc_trig[1]) q1 <= (q1 >= 4'd5) ? 4'd0 : q1 + 1'b1; // SW2 秒十位
        else if (inc_trig[0]) q0 <= (q0 >= 4'd9) ? 4'd0 : q0 + 1'b1; // SW1 秒個位
    end else if (mode_set_alarm) begin
        // 按住 SW7：同樣邏輯改鬧鐘
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
// 4. 鬧鐘比對與 LED
//---------------------------------------------------------
wire alarm_match = ({q5,q4,q3,q2,q1,q0} == {al_q5,al_q4,al_q3,al_q2,al_q1,al_q0});
assign led_com = 1'b0;

always @(*) begin
    led = (alarm_match && blink_clk && !is_setting) ? 12'hFFF : 12'h000;
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

always @(*) scanout = cnt_scan[15:13];

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