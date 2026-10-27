module test2 (clk, reset, sw, segout, scanout, led, led_com, buzzer);

input clk, reset;
input [7:0] sw;
output reg [7:0] segout;
output reg [2:0] scanout;
output reg [11:0] led;
output led_com;
output buzzer;

parameter CLK_HZ    = 10_000_000;
parameter BTN_LOW   = 1'b0;
parameter LED_COM   = 1'b0;
parameter BUZZ_IDLE = 1'b0;
parameter VOL       = 1;

localparam [25:0] BTN_MAX   = CLK_HZ / 100 - 1;
localparam [25:0] SND_MAX   = CLK_HZ / 64 - 1;
localparam [19:0] NOISE_MAX = CLK_HZ / 8000 - 1;

localparam [11:0] RED = 12'b001001001001;
localparam [11:0] YEL = 12'b010010010010;
localparam [11:0] GRN = 12'b100100100100;

localparam [15:0] TA = 16'b0100101111011110;
localparam [15:0] TB = 16'b1000100101011100;
localparam [15:0] TC = 16'b1000100011001010;
localparam [15:0] TD = 16'b0111100010011110;
localparam [15:0] TE = 16'b1111101111011110;
localparam [15:0] TF = 16'b1111101111001010;
localparam [15:0] TG = 16'b1100011101010110;

localparam [3:0] NSC = 4'd15;

reg [5:0]  ra, rb, rc, rd, re, rf, rg, rp;
reg [15:0] ring, ring2;
reg [5:0]  x, xp, f6, s6, rpd;
reg        dir, ydir, m;
reg [1:0]  y;
reg [3:0]  tp;
reg [11:0] lr;
reg [15:0] lfsr;

reg [3:0]  sc;
reg [7:0]  st;
reg [5:0]  hc;
reg [25:0] ctk;
reg [3:0]  req;

reg [7:0]  s1, s2, bnow, press;
reg [25:0] cbtn;
reg [2:0]  sp;
reg        paused, mute, mir;

wire [7:0] lvl   = BTN_LOW ? ~s2 : s2;
wire       turbo = bnow[7];
wire [7:0] nst   = st + 1'b1;
wire [3:0] nsc   = (sc == NSC) ? 4'd0 : sc + 1'b1;
wire [3:0] psc   = (sc == 4'd0) ? NSC : sc - 1'b1;
wire [5:0] r6    = {s6[1], s6[2], s6[3], s6[4], s6[5], s6[0]};
wire [15:0] rr   = ring | ring2;

function [11:0] dbl;
    input [5:0] v;
    dbl = {v[0], v[0], v[1], v[1], v[2], v[2], v[3], v[3], v[4], v[4], v[5], v[5]};
endfunction

function [5:0] rev6;
    input [5:0] v;
    rev6 = {v[0], v[1], v[2], v[3], v[4], v[5]};
endfunction

function [11:0] rev12;
    input [11:0] v;
    rev12 = {v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8], v[9], v[10], v[11]};
endfunction

function [25:0] tmax;
    input [2:0] s;
    case (s)
        3'd0:    tmax = CLK_HZ / 110 - 1;
        3'd1:    tmax = CLK_HZ / 75 - 1;
        3'd2:    tmax = CLK_HZ / 50 - 1;
        3'd3:    tmax = CLK_HZ / 35 - 1;
        default: tmax = CLK_HZ / 25 - 1;
    endcase
endfunction

function [7:0] slen;
    input [3:0] n;
    case (n)
        4'd0:    slen = 8'd8;
        4'd1:    slen = 8'd64;
        4'd2:    slen = 8'd32;
        4'd3:    slen = 8'd40;
        4'd4:    slen = 8'd30;
        4'd5:    slen = 8'd40;
        4'd6:    slen = 8'd40;
        4'd7:    slen = 8'd14;
        4'd8:    slen = 8'd72;
        4'd9:    slen = 8'd13;
        4'd10:   slen = 8'd12;
        4'd11:   slen = 8'd24;
        4'd12:   slen = 8'd36;
        4'd13:   slen = 8'd12;
        4'd14:   slen = 8'd40;
        default: slen = 8'd20;
    endcase
endfunction

function [5:0] fhold;
    input [3:0] n;
    input [7:0] t;
    case (n)
        4'd0:    fhold = (t == 8'd7) ? 6'd15 : (t[0] ? 6'd8 : 6'd25);
        4'd1:    fhold = 6'd8 - t[5:3];
        4'd2:    fhold = 6'd2;
        4'd3:    fhold = 6'd2;
        4'd4:    fhold = 6'd3;
        4'd5:    fhold = 6'd2;
        4'd6:    fhold = 6'd1 + t[5:3];
        4'd7:    fhold = 6'd4;
        4'd8:    fhold = (t < 8'd36) ? 6'd7 - t / 6 : 6'd1;
        4'd9:    fhold = 6'd3;
        4'd10:   fhold = 6'd4;
        4'd11:   fhold = 6'd4;
        4'd12:   fhold = 6'd5;
        4'd13:   fhold = 6'd5 - t[3:2];
        4'd14:   fhold = 6'd1 + t / 10;
        default: fhold = (t < 8'd12) ? 6'd4 : 6'd15;
    endcase
endfunction

function [9:0] snd;
    input [6:0] a;
    case (a)
            7'd0: snd = {5'd0, 4'd1, 1'b1};
            7'd1: snd = {5'd20, 4'd2, 1'b1};
            7'd2: snd = {5'd12, 4'd3, 1'b0};
            7'd3: snd = {5'd17, 4'd8, 1'b1};
            7'd4: snd = {5'd30, 4'd1, 1'b0};
            7'd5: snd = {5'd29, 4'd1, 1'b0};
            7'd6: snd = {5'd28, 4'd1, 1'b0};
            7'd7: snd = {5'd27, 4'd1, 1'b0};
            7'd8: snd = {5'd26, 4'd1, 1'b0};
            7'd9: snd = {5'd25, 4'd1, 1'b0};
            7'd10: snd = {5'd24, 4'd1, 1'b0};
            7'd11: snd = {5'd23, 4'd1, 1'b0};
            7'd12: snd = {5'd22, 4'd1, 1'b0};
            7'd13: snd = {5'd21, 4'd1, 1'b0};
            7'd14: snd = {5'd20, 4'd1, 1'b0};
            7'd15: snd = {5'd19, 4'd1, 1'b0};
            7'd16: snd = {5'd18, 4'd1, 1'b0};
            7'd17: snd = {5'd17, 4'd1, 1'b0};
            7'd18: snd = {5'd16, 4'd1, 1'b0};
            7'd19: snd = {5'd15, 4'd1, 1'b0};
            7'd20: snd = {5'd14, 4'd1, 1'b0};
            7'd21: snd = {5'd13, 4'd1, 1'b1};
            7'd22: snd = {5'd1, 4'd2, 1'b0};
            7'd23: snd = {5'd5, 4'd2, 1'b0};
            7'd24: snd = {5'd8, 4'd2, 1'b0};
            7'd25: snd = {5'd13, 4'd2, 1'b0};
            7'd26: snd = {5'd17, 4'd2, 1'b0};
            7'd27: snd = {5'd20, 4'd2, 1'b0};
            7'd28: snd = {5'd25, 4'd2, 1'b0};
            7'd29: snd = {5'd29, 4'd4, 1'b1};
            7'd30: snd = {5'd31, 4'd15, 1'b0};
            7'd31: snd = {5'd31, 4'd12, 1'b0};
            7'd32: snd = {5'd31, 4'd6, 1'b1};
            7'd33: snd = {5'd1, 4'd1, 1'b0};
            7'd34: snd = {5'd3, 4'd1, 1'b0};
            7'd35: snd = {5'd5, 4'd1, 1'b0};
            7'd36: snd = {5'd7, 4'd1, 1'b0};
            7'd37: snd = {5'd9, 4'd1, 1'b0};
            7'd38: snd = {5'd11, 4'd1, 1'b0};
            7'd39: snd = {5'd13, 4'd1, 1'b1};
            7'd40: snd = {5'd8, 4'd6, 1'b0};
            7'd41: snd = {5'd13, 4'd6, 1'b0};
            7'd42: snd = {5'd17, 4'd6, 1'b0};
            7'd43: snd = {5'd20, 4'd14, 1'b0};
            7'd44: snd = {5'd0, 4'd4, 1'b0};
            7'd45: snd = {5'd17, 4'd6, 1'b0};
            7'd46: snd = {5'd20, 4'd15, 1'b1};
            7'd47: snd = {5'd1, 4'd3, 1'b0};
            7'd48: snd = {5'd0, 4'd2, 1'b1};
            7'd49: snd = {5'd10, 4'd10, 1'b0};
            7'd50: snd = {5'd17, 4'd10, 1'b0};
            7'd51: snd = {5'd10, 4'd10, 1'b0};
            7'd52: snd = {5'd17, 4'd10, 1'b1};
            7'd53: snd = {5'd25, 4'd1, 1'b1};
            7'd54: snd = {5'd8, 4'd3, 1'b0};
            7'd55: snd = {5'd15, 4'd3, 1'b0};
            7'd56: snd = {5'd8, 4'd2, 1'b1};
            7'd57: snd = {5'd8, 4'd8, 1'b0};
            7'd58: snd = {5'd7, 4'd8, 1'b0};
            7'd59: snd = {5'd6, 4'd8, 1'b0};
            7'd60: snd = {5'd5, 4'd15, 1'b1};
            7'd61: snd = {5'd29, 4'd1, 1'b1};
            7'd62: snd = {5'd17, 4'd2, 1'b0};
            7'd63: snd = {5'd13, 4'd2, 1'b1};
            7'd64: snd = {5'd28, 4'd1, 1'b0};
            7'd65: snd = {5'd22, 4'd1, 1'b0};
            7'd66: snd = {5'd30, 4'd1, 1'b0};
            7'd67: snd = {5'd25, 4'd1, 1'b0};
            7'd68: snd = {5'd29, 4'd1, 1'b0};
            7'd69: snd = {5'd23, 4'd1, 1'b1};
        default: snd = {5'd0, 4'd1, 1'b1};
    endcase
endfunction

function [6:0] sfx_at;
    input [3:0] k;
    case (k)
            4'd0: sfx_at = 7'd0;
            4'd1: sfx_at = 7'd1;
            4'd2: sfx_at = 7'd2;
            4'd3: sfx_at = 7'd4;
            4'd4: sfx_at = 7'd22;
            4'd5: sfx_at = 7'd30;
            4'd6: sfx_at = 7'd33;
            4'd7: sfx_at = 7'd40;
            4'd8: sfx_at = 7'd47;
            4'd9: sfx_at = 7'd49;
            4'd10: sfx_at = 7'd53;
            4'd11: sfx_at = 7'd54;
            4'd12: sfx_at = 7'd57;
            4'd13: sfx_at = 7'd61;
            4'd14: sfx_at = 7'd62;
            4'd15: sfx_at = 7'd64;
        default: sfx_at = 7'd0;
    endcase
endfunction

function [19:0] half;
    input [4:0] n;
    case (n)
            5'd1: half = CLK_HZ / 1046;
            5'd2: half = CLK_HZ / 1108;
            5'd3: half = CLK_HZ / 1174;
            5'd4: half = CLK_HZ / 1244;
            5'd5: half = CLK_HZ / 1318;
            5'd6: half = CLK_HZ / 1396;
            5'd7: half = CLK_HZ / 1480;
            5'd8: half = CLK_HZ / 1568;
            5'd9: half = CLK_HZ / 1662;
            5'd10: half = CLK_HZ / 1760;
            5'd11: half = CLK_HZ / 1864;
            5'd12: half = CLK_HZ / 1976;
            5'd13: half = CLK_HZ / 2092;
            5'd14: half = CLK_HZ / 2218;
            5'd15: half = CLK_HZ / 2350;
            5'd16: half = CLK_HZ / 2490;
            5'd17: half = CLK_HZ / 2638;
            5'd18: half = CLK_HZ / 2794;
            5'd19: half = CLK_HZ / 2960;
            5'd20: half = CLK_HZ / 3136;
            5'd21: half = CLK_HZ / 3322;
            5'd22: half = CLK_HZ / 3520;
            5'd23: half = CLK_HZ / 3730;
            5'd24: half = CLK_HZ / 3952;
            5'd25: half = CLK_HZ / 4186;
            5'd26: half = CLK_HZ / 4434;
            5'd27: half = CLK_HZ / 4698;
            5'd28: half = CLK_HZ / 4978;
            5'd29: half = CLK_HZ / 5274;
            5'd30: half = CLK_HZ / 5588;
        default: half = 20'd0;
    endcase
endfunction

function [3:0] btn_sfx;
    input [7:0] p;
    casez (p)
        8'b???????1: btn_sfx = 4'd2;
        8'b??????10: btn_sfx = 4'd14;
        8'b?????100: btn_sfx = 4'd6;
        8'b????1000: btn_sfx = 4'd11;
        8'b???10000: btn_sfx = 4'd10;
        8'b??100000: btn_sfx = 4'd13;
        8'b?1000000: btn_sfx = 4'd3;
        8'b10000000: btn_sfx = 4'd4;
        default:     btn_sfx = 4'd0;
    endcase
endfunction

task set7;
    input [5:0] a, b, c, d, e, f, g, p;
    begin
        ra <= a; rb <= b; rc <= c; rd <= d;
        re <= e; rf <= f; rg <= g; rp <= p;
    end
endtask

task load;
    input [3:0] n;
    begin
        set7(6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000);
        ring  <= 16'b0;
        ring2 <= 16'b0;
        case (n)
            4'd0: begin
                set7(6'b001100, 6'b001100, 6'b001100, 6'b001100, 6'b000000, 6'b000000, 6'b001100, 6'b000000);
                lr  <= RED;
                req <= 4'd1;
            end
            4'd1: begin
                ring <= 16'b1110000000000000;
                lr   <= 12'b000000000001;
            end
            4'd2: begin
                ring  <= 16'b1110000000000000;
                ring2 <= 16'b0000000011100000;
                lr    <= 12'b100000100000;
                req   <= 4'd3;
            end
            4'd3: begin
                x   <= 6'b100000;
                xp  <= 6'b000000;
                dir <= 1'b0;
                lr  <= dbl(6'b100000);
            end
            4'd4: begin
                ra <= 6'b100100;
                rg <= 6'b010010;
                rd <= 6'b001001;
                lr <= 12'b100010001000;
            end
            4'd5: begin
                lr  <= 12'b0;
                req <= 4'd15;
            end
            4'd6: begin
                x    <= 6'b100000;
                dir  <= 1'b0;
                y    <= 2'd0;
                ydir <= 1'b0;
                lr   <= dbl(6'b100000);
            end
            4'd7: begin
                x   <= 6'b100000;
                m   <= 1'b0;
                rpd <= 6'b111111;
                rp  <= 6'b111111;
                lr  <= dbl(6'b111111);
            end
            4'd8: begin
                s6  <= 6'b000001;
                lr  <= 12'b000000000001;
                req <= 4'd4;
            end
            4'd9: begin
                f6  <= 6'b000000;
                lr  <= 12'b0;
                req <= 4'd6;
            end
            4'd10: begin
                set7(6'b100001, 6'b100001, 6'b100001, 6'b100001, 6'b100001, 6'b100001, 6'b100001, 6'b000000);
                lr  <= dbl(6'b100001);
                req <= 4'd3;
            end
            4'd11: begin
                set7(6'b001100, 6'b001100, 6'b001100, 6'b001100, 6'b001100, 6'b001100, 6'b001100, 6'b000000);
                lr  <= RED;
                req <= 4'd8;
            end
            4'd12: begin
                tp  <= 4'd0;
                lr  <= 12'b100100100100;
                req <= 4'd13;
            end
            4'd13: begin
                rg  <= 6'b001100;
                lr  <= dbl(6'b001100);
                req <= 4'd5;
            end
            4'd14: begin
                lr  <= 12'b0;
                req <= 4'd15;
            end
            default: begin
                set7(6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111);
                lr  <= 12'b111111111111;
                req <= 4'd7;
            end
        endcase
    end
endtask

task step;
    begin
        case (sc)
            4'd0: begin
                case (nst)
                    8'd2: begin
                        set7(6'b001100, 6'b001100, 6'b000000, 6'b001100, 6'b001100, 6'b000000, 6'b001100, 6'b000000);
                        lr <= RED; req <= 4'd1;
                    end
                    8'd4: begin
                        set7(6'b000000, 6'b001100, 6'b001100, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000);
                        lr <= YEL; req <= 4'd1;
                    end
                    8'd6: begin
                        set7(6'b001100, 6'b000100, 6'b001100, 6'b001100, 6'b001100, 6'b001100, 6'b000000, 6'b000000);
                        lr <= GRN; req <= 4'd7;
                    end
                    8'd7: begin
                        set7(6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111);
                        lr <= 12'b111111111111;
                    end
                    default: begin
                        set7(6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000);
                        lr <= 12'b0;
                    end
                endcase
            end

            4'd1: begin
                ring <= {ring[0], ring[15:1]};
                lr   <= {lr[10:0], lr[11]};
                if (st[3:0] == 4'd15) req <= 4'd10;
            end

            4'd2: begin
                ring  <= {ring[0], ring[15:1]};
                ring2 <= {ring2[14:0], ring2[15]};
                lr    <= {lr[10:0], lr[11]};
                if (st[2:0] == 3'd7) req <= 4'd14;
            end

            4'd3: begin
                rg <= x;
                rp <= xp;
                xp <= x;
                lr <= dbl(x);
                if (dir == 1'b0) begin
                    if (x == 6'b000001) begin dir <= 1'b1; x <= 6'b000010; req <= 4'd13; end
                    else x <= x >> 1;
                end else begin
                    if (x == 6'b100000) begin dir <= 1'b0; x <= 6'b010000; req <= 4'd13; end
                    else x <= x << 1;
                end
            end

            4'd4: begin
                ra <= {ra[0], ra[5:1]};
                rg <= {rg[0], rg[5:1]};
                rd <= {rd[0], rd[5:1]};
                lr <= {lr[0], lr[11:1]};
            end

            4'd5: begin
                ra <= lfsr[5:0] & lfsr[11:6];
                rg <= ra;
                rd <= rg;
                rp <= rd;
                lr <= lfsr[11:0] & GRN;
                if (st[3:0] == 4'd0) req <= 4'd15;
            end

            4'd6: begin
                ra <= (y == 2'd0) ? x : 6'b000000;
                rg <= (y == 2'd1) ? x : 6'b000000;
                rd <= (y == 2'd2) ? x : 6'b000000;
                lr <= dbl(x);
                if (dir == 1'b0) begin
                    if (x == 6'b000001) begin dir <= 1'b1; x <= 6'b000010; req <= 4'd14; end
                    else x <= x >> 1;
                end else begin
                    if (x == 6'b100000) begin dir <= 1'b0; x <= 6'b010000; req <= 4'd14; end
                    else x <= x << 1;
                end
                if (ydir == 1'b0) begin
                    if (y == 2'd2) begin ydir <= 1'b1; y <= 2'd1; req <= 4'd14; end
                    else y <= y + 1'b1;
                end else begin
                    if (y == 2'd0) begin ydir <= 1'b0; y <= 2'd1; req <= 4'd14; end
                    else y <= y - 1'b1;
                end
            end

            4'd7: begin
                ra  <= x;
                rd  <= x;
                re  <= x;
                rf  <= x;
                rb  <= m ? x : 6'b000000;
                rc  <= m ? x : 6'b000000;
                rp  <= rpd & ~x;
                rpd <= rpd & ~x;
                lr  <= dbl(rpd & ~x);
                m   <= ~m;
                if (m) x <= x >> 1;
                else   req <= 4'd11;
            end

            4'd8: begin
                s6 <= {s6[4:0], s6[5]};
                ra <= ({6{s6[0]}} & 6'b101010) | ({6{r6[0]}} & 6'b010101);
                rb <= ({6{s6[1]}} & 6'b101010) | ({6{r6[1]}} & 6'b010101);
                rc <= ({6{s6[2]}} & 6'b101010) | ({6{r6[2]}} & 6'b010101);
                rd <= ({6{s6[3]}} & 6'b101010) | ({6{r6[3]}} & 6'b010101);
                re <= ({6{s6[4]}} & 6'b101010) | ({6{r6[4]}} & 6'b010101);
                rf <= ({6{s6[5]}} & 6'b101010) | ({6{r6[5]}} & 6'b010101);
                lr <= {lr[10:0], lr[11]};
                if (s6 == 6'b000001) req <= 4'd10;
            end

            4'd9: begin
                f6 <= (nst <= 8'd6) ? {f6[4:0], 1'b1} : {f6[4:0], 1'b0};
                set7(f6, f6, f6, f6, f6, f6, f6, 6'b000000);
                lr <= dbl(f6);
                if (nst == 8'd7) req <= 4'd5;
            end

            4'd10: begin
                case (nst % 6)
                    8'd0: begin set7(6'b100001, 6'b100001, 6'b100001, 6'b100001, 6'b100001, 6'b100001, 6'b100001, 6'b000000); lr <= dbl(6'b100001); req <= 4'd3; end
                    8'd1: begin set7(6'b110011, 6'b110011, 6'b110011, 6'b110011, 6'b110011, 6'b110011, 6'b110011, 6'b000000); lr <= dbl(6'b110011); end
                    8'd2: begin set7(6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111); lr <= dbl(6'b111111); req <= 4'd14; end
                    8'd3: begin set7(6'b011110, 6'b011110, 6'b011110, 6'b011110, 6'b011110, 6'b011110, 6'b011110, 6'b000000); lr <= dbl(6'b011110); end
                    8'd4: begin set7(6'b001100, 6'b001100, 6'b001100, 6'b001100, 6'b001100, 6'b001100, 6'b001100, 6'b000000); lr <= dbl(6'b001100); end
                    default: begin set7(6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000); lr <= 12'b0; end
                endcase
            end

            4'd11: begin
                case (nst % 6)
                    8'd0: begin set7(6'b001100, 6'b001100, 6'b001100, 6'b001100, 6'b001100, 6'b001100, 6'b001100, 6'b000000); lr <= RED; req <= 4'd8; end
                    8'd2: begin set7(6'b011110, 6'b011110, 6'b011110, 6'b011110, 6'b011110, 6'b011110, 6'b011110, 6'b000000); lr <= RED | YEL; req <= 4'd8; end
                    default: begin set7(6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000); lr <= 12'b0; end
                endcase
            end

            4'd12: begin
                ra <= {ra[4:0], TA[4'd15 - tp]};
                rb <= {rb[4:0], TB[4'd15 - tp]};
                rc <= {rc[4:0], TC[4'd15 - tp]};
                rd <= {rd[4:0], TD[4'd15 - tp]};
                re <= {re[4:0], TE[4'd15 - tp]};
                rf <= {rf[4:0], TF[4'd15 - tp]};
                rg <= {rg[4:0], TG[4'd15 - tp]};
                tp <= tp + 1'b1;
                lr <= {lr[10:0], lr[11]};
            end

            4'd13: begin
                case (nst % 4)
                    8'd0: begin set7(6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b001100, 6'b000000); lr <= dbl(6'b001100); end
                    8'd1: begin set7(6'b011110, 6'b011110, 6'b011110, 6'b011110, 6'b011110, 6'b011110, 6'b011110, 6'b011110); lr <= dbl(6'b011110); req <= 4'd5; end
                    8'd2: begin set7(6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b000000, 6'b000000); lr <= 12'b111111111111; end
                    default: begin set7(6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000); lr <= 12'b0; end
                endcase
            end

            4'd14: begin
                ra <= lfsr[5:0]   & lfsr[11:6];
                rb <= lfsr[6:1]   & lfsr[12:7];
                rc <= lfsr[7:2]   & lfsr[13:8];
                rd <= lfsr[8:3]   & lfsr[14:9];
                re <= lfsr[9:4]   & lfsr[15:10];
                rf <= lfsr[10:5]  & lfsr[5:0];
                rg <= lfsr[11:6]  & lfsr[3:0] << 2;
                rp <= lfsr[15:10] & lfsr[9:4];
                lr <= lfsr[11:0];
                if (st % 6 == 0) req <= 4'd15;
            end

            default: begin
                if (nst < 8'd12) begin
                    case (nst % 3)
                        8'd0: begin set7(6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111); lr <= 12'b111111111111; end
                        8'd1: begin set7(6'b101010, 6'b101010, 6'b101010, 6'b101010, 6'b101010, 6'b101010, 6'b010101, 6'b000000); lr <= RED | GRN; end
                        default: begin set7(6'b010101, 6'b010101, 6'b010101, 6'b010101, 6'b010101, 6'b010101, 6'b101010, 6'b000000); lr <= YEL; end
                    endcase
                end else begin
                    set7(6'b010000, 6'b000100, 6'b001100, 6'b010100, 6'b011100, 6'b010000, 6'b011100, 6'b000000);
                    lr <= RED;
                    if (nst == 8'd12) req <= 4'd12;
                end
            end
        endcase
    end
endtask

always @(posedge clk or negedge reset) begin
    if (!reset) begin
        s1    <= BTN_LOW ? 8'hFF : 8'h00;
        s2    <= BTN_LOW ? 8'hFF : 8'h00;
        cbtn  <= 26'd0;
        bnow  <= 8'h00;
        press <= 8'h00;
    end else begin
        s1 <= sw;
        s2 <= s1;
        if (cbtn >= BTN_MAX) begin
            cbtn  <= 26'd0;
            press <= lvl & ~bnow;
            bnow  <= lvl;
        end else begin
            cbtn  <= cbtn + 1'b1;
            press <= 8'h00;
        end
    end
end

always @(posedge clk or negedge reset) begin
    if (!reset) begin
        sp     <= 3'd2;
        paused <= 1'b0;
        mute   <= 1'b0;
        mir    <= 1'b0;
    end else begin
        if (press[2] && sp != 3'd0) sp <= sp - 1'b1;
        if (press[3] && sp != 3'd4) sp <= sp + 1'b1;
        if (press[4]) paused <= ~paused;
        if (press[5]) mute   <= ~mute;
        if (press[6]) mir    <= ~mir;
    end
end

always @(posedge clk or negedge reset) begin
    if (!reset) lfsr <= 16'hACE1;
    else        lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
end

wire [25:0] tm = turbo ? (tmax(sp) >> 2) : tmax(sp);

always @(posedge clk or negedge reset) begin
    if (!reset) begin
        sc   <= 4'd0;
        st   <= 8'd0;
        hc   <= 6'd0;
        ctk  <= 26'd0;
        req  <= 4'd0;
        x    <= 6'b100000;
        xp   <= 6'b000000;
        f6   <= 6'b000000;
        s6   <= 6'b000001;
        rpd  <= 6'b111111;
        dir  <= 1'b0;
        ydir <= 1'b0;
        m    <= 1'b0;
        y    <= 2'd0;
        tp   <= 4'd0;
        load(4'd0);
    end else begin
        req <= btn_sfx(press);
        if (press[0]) begin
            sc  <= nsc;
            st  <= 8'd0;
            hc  <= 6'd0;
            ctk <= 26'd0;
            load(nsc);
            req <= 4'd2;
        end else if (press[1]) begin
            sc  <= psc;
            st  <= 8'd0;
            hc  <= 6'd0;
            ctk <= 26'd0;
            load(psc);
            req <= 4'd14;
        end else if (!paused) begin
            if (ctk >= tm) begin
                ctk <= 26'd0;
                if (hc + 1'b1 >= fhold(sc, st)) begin
                    hc <= 6'd0;
                    if (nst >= slen(sc)) begin
                        sc <= nsc;
                        st <= 8'd0;
                        load(nsc);
                    end else begin
                        st <= nst;
                        step;
                    end
                end else begin
                    hc <= hc + 1'b1;
                end
            end else begin
                ctk <= ctk + 1'b1;
            end
        end
    end
end

reg [6:0]  pa;
reg [3:0]  sleft;
reg        playing;
reg [25:0] cs;
reg [19:0] tc;
reg        buzz;

wire [9:0] ent  = snd(pa);
wire [4:0] note = playing ? ent[9:5] : 5'd0;
wire [9:0] e0   = snd(sfx_at(req));
wire [9:0] e1   = snd(pa + 1'b1);

always @(posedge clk or negedge reset) begin
    if (!reset) begin
        pa      <= 7'd0;
        sleft   <= 4'd0;
        playing <= 1'b0;
        cs      <= 26'd0;
        tc      <= 20'd0;
        buzz    <= 1'b0;
    end else begin
        if (req != 4'd0) begin
            pa      <= sfx_at(req);
            sleft   <= e0[4:1];
            playing <= 1'b1;
            cs      <= 26'd0;
        end else if (playing) begin
            if (cs >= SND_MAX) begin
                cs <= 26'd0;
                if (sleft <= 4'd1) begin
                    if (ent[0]) playing <= 1'b0;
                    else begin
                        pa    <= pa + 1'b1;
                        sleft <= e1[4:1];
                    end
                end else begin
                    sleft <= sleft - 1'b1;
                end
            end else begin
                cs <= cs + 1'b1;
            end
        end

        if (mute || note == 5'd0) begin
            tc   <= 20'd0;
            buzz <= 1'b0;
        end else if (note == 5'd31) begin
            if (tc >= NOISE_MAX) begin
                tc   <= 20'd0;
                buzz <= lfsr[0];
            end else begin
                tc <= tc + 1'b1;
            end
        end else if (tc >= half(note) - 1'b1) begin
            tc   <= 20'd0;
            buzz <= ~buzz;
        end else begin
            tc <= tc + 1'b1;
        end
    end
end

wire [19:0] lim    = (note == 5'd31) ? NOISE_MAX : half(note) - 1'b1;
wire [23:0] on_len = (lim * VOL) >> 3;
wire        buzz_q = buzz & (tc < on_len);

assign buzzer  = buzz_q ^ BUZZ_IDLE;
assign led_com = LED_COM;

reg [23:0] cnt;
always @(posedge clk or negedge reset) begin
    if (!reset) cnt <= 24'd0;
    else        cnt <= cnt + 1'b1;
end

wire blink = cnt[22];

wire [5:0] A0 = ra | rr[15:10];
wire [5:0] B0 = rb | {5'b00000, rr[9]};
wire [5:0] C0 = rc | {5'b00000, rr[8]};
wire [5:0] D0 = rd | {rr[2], rr[3], rr[4], rr[5], rr[6], rr[7]};
wire [5:0] E0 = re | {rr[1], 5'b00000};
wire [5:0] F0 = rf | {rr[0], 5'b00000};
wire [5:0] G0 = rg;
wire [5:0] P0 = rp | {6{paused & blink}};

wire [5:0] A1 = mir ? rev6(A0) : A0;
wire [5:0] B1 = mir ? rev6(F0) : B0;
wire [5:0] C1 = mir ? rev6(E0) : C0;
wire [5:0] D1 = mir ? rev6(D0) : D0;
wire [5:0] E1 = mir ? rev6(C0) : E0;
wire [5:0] F1 = mir ? rev6(B0) : F0;
wire [5:0] G1 = mir ? rev6(G0) : G0;
wire [5:0] P1 = mir ? rev6(P0) : P0;

always @(*) scanout = cnt[15:13];

always @(*) begin
    case (scanout)
        3'd0:    segout = {P1[5], G1[5], F1[5], E1[5], D1[5], C1[5], B1[5], A1[5]};
        3'd1:    segout = {P1[4], G1[4], F1[4], E1[4], D1[4], C1[4], B1[4], A1[4]};
        3'd2:    segout = {P1[3], G1[3], F1[3], E1[3], D1[3], C1[3], B1[3], A1[3]};
        3'd3:    segout = {P1[2], G1[2], F1[2], E1[2], D1[2], C1[2], B1[2], A1[2]};
        3'd4:    segout = {P1[1], G1[1], F1[1], E1[1], D1[1], C1[1], B1[1], A1[1]};
        3'd5:    segout = {P1[0], G1[0], F1[0], E1[0], D1[0], C1[0], B1[0], A1[0]};
        default: segout = 8'b00000000;
    endcase
end

always @(*) begin
    if (paused)   led = blink ? lr : 12'b0;
    else if (mir) led = rev12(lr);
    else          led = lr;
end

endmodule