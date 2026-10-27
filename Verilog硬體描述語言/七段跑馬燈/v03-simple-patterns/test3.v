module test3 (clk, reset, segout, scanout, led, led_com);

input clk, reset;
output reg [7:0] segout;
output reg [2:0] scanout;
output reg [11:0] led;
output led_com;

parameter CLK_HZ  = 10_000_000;
parameter LED_COM = 1'b0;

localparam [25:0] TICK = CLK_HZ / 50 - 1;

localparam [11:0] RED = 12'b001001001001;
localparam [11:0] YEL = 12'b010010010010;
localparam [11:0] GRN = 12'b100100100100;

localparam [3:0] NSC = 4'd13;

reg [5:0]  ra, rb, rc, rd, re, rf, rg, rp;
reg [15:0] ring, ring2;
reg [5:0]  x, xp, f6, s6, rpd;
reg        dir, ydir, m;
reg [1:0]  y;
reg [11:0] lr;
reg [15:0] lfsr;

reg [3:0]  sc;
reg [7:0]  st;
reg [5:0]  hc;
reg [25:0] ctk;
reg [15:0] cnt;

wire [7:0]  nst = st + 1'b1;
wire [3:0]  nsc = (sc == NSC) ? 4'd0 : sc + 1'b1;
wire [5:0]  r6  = {s6[1], s6[2], s6[3], s6[4], s6[5], s6[0]};
wire [15:0] rr  = ring | ring2;

function [11:0] dbl;
    input [5:0] v;
    dbl = {v[0], v[0], v[1], v[1], v[2], v[2], v[3], v[3], v[4], v[4], v[5], v[5]};
endfunction

function [7:0] slen;
    input [3:0] n;
    case (n)
        4'd0:    slen = 8'd64;
        4'd1:    slen = 8'd32;
        4'd2:    slen = 8'd40;
        4'd3:    slen = 8'd30;
        4'd4:    slen = 8'd40;
        4'd5:    slen = 8'd40;
        4'd6:    slen = 8'd14;
        4'd7:    slen = 8'd72;
        4'd8:    slen = 8'd13;
        4'd9:    slen = 8'd12;
        4'd10:   slen = 8'd24;
        4'd11:   slen = 8'd12;
        4'd12:   slen = 8'd40;
        default: slen = 8'd12;
    endcase
endfunction

function [5:0] fhold;
    input [3:0] n;
    input [7:0] t;
    case (n)
        4'd0:    fhold = 6'd8 - t[5:3];
        4'd1:    fhold = 6'd2;
        4'd2:    fhold = 6'd2;
        4'd3:    fhold = 6'd3;
        4'd4:    fhold = 6'd2;
        4'd5:    fhold = 6'd1 + t[5:3];
        4'd6:    fhold = 6'd4;
        4'd7:    fhold = (t < 8'd36) ? 6'd7 - t / 6 : 6'd1;
        4'd8:    fhold = 6'd3;
        4'd9:    fhold = 6'd4;
        4'd10:   fhold = 6'd4;
        4'd11:   fhold = 6'd5 - t[3:2];
        4'd12:   fhold = 6'd1 + t / 10;
        default: fhold = 6'd4;
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
        ring  <= 16'b0000000000000000;
        ring2 <= 16'b0000000000000000;
        case (n)
            4'd0: begin
                ring <= 16'b1110000000000000;
                lr   <= 12'b000000000001;
            end
            4'd1: begin
                ring  <= 16'b1110000000000000;
                ring2 <= 16'b0000000011100000;
                lr    <= 12'b100000100000;
            end
            4'd2: begin
                x   <= 6'b100000;
                xp  <= 6'b000000;
                dir <= 1'b0;
                lr  <= dbl(6'b100000);
            end
            4'd3: begin
                ra <= 6'b100100;
                rg <= 6'b010010;
                rd <= 6'b001001;
                lr <= 12'b100010001000;
            end
            4'd4: begin
                lr <= 12'b000000000000;
            end
            4'd5: begin
                x    <= 6'b100000;
                dir  <= 1'b0;
                y    <= 2'd0;
                ydir <= 1'b0;
                lr   <= dbl(6'b100000);
            end
            4'd6: begin
                x   <= 6'b100000;
                m   <= 1'b0;
                rpd <= 6'b111111;
                rp  <= 6'b111111;
                lr  <= dbl(6'b111111);
            end
            4'd7: begin
                s6 <= 6'b000001;
                lr <= 12'b000000000001;
            end
            4'd8: begin
                f6 <= 6'b000000;
                lr <= 12'b000000000000;
            end
            4'd9: begin
                set7(6'b100001, 6'b100001, 6'b100001, 6'b100001, 6'b100001, 6'b100001, 6'b100001, 6'b000000);
                lr <= dbl(6'b100001);
            end
            4'd10: begin
                set7(6'b001100, 6'b001100, 6'b001100, 6'b001100, 6'b001100, 6'b001100, 6'b001100, 6'b000000);
                lr <= RED;
            end
            4'd11: begin
                rg <= 6'b001100;
                lr <= dbl(6'b001100);
            end
            4'd12: begin
                lr <= 12'b000000000000;
            end
            default: begin
                set7(6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111);
                lr <= 12'b111111111111;
            end
        endcase
    end
endtask

task step;
    begin
        case (sc)
            4'd0: begin
                ring <= {ring[0], ring[15:1]};
                lr   <= {lr[10:0], lr[11]};
            end

            4'd1: begin
                ring  <= {ring[0], ring[15:1]};
                ring2 <= {ring2[14:0], ring2[15]};
                lr    <= {lr[10:0], lr[11]};
            end

            4'd2: begin
                rg <= x;
                rp <= xp;
                xp <= x;
                lr <= dbl(x);
                if (dir == 1'b0) begin
                    if (x == 6'b000001) begin dir <= 1'b1; x <= 6'b000010; end
                    else x <= x >> 1;
                end else begin
                    if (x == 6'b100000) begin dir <= 1'b0; x <= 6'b010000; end
                    else x <= x << 1;
                end
            end

            4'd3: begin
                ra <= {ra[0], ra[5:1]};
                rg <= {rg[0], rg[5:1]};
                rd <= {rd[0], rd[5:1]};
                lr <= {lr[0], lr[11:1]};
            end

            4'd4: begin
                ra <= lfsr[5:0] & lfsr[11:6];
                rg <= ra;
                rd <= rg;
                rp <= rd;
                lr <= lfsr[11:0] & GRN;
            end

            4'd5: begin
                ra <= (y == 2'd0) ? x : 6'b000000;
                rg <= (y == 2'd1) ? x : 6'b000000;
                rd <= (y == 2'd2) ? x : 6'b000000;
                lr <= dbl(x);
                if (dir == 1'b0) begin
                    if (x == 6'b000001) begin dir <= 1'b1; x <= 6'b000010; end
                    else x <= x >> 1;
                end else begin
                    if (x == 6'b100000) begin dir <= 1'b0; x <= 6'b010000; end
                    else x <= x << 1;
                end
                if (ydir == 1'b0) begin
                    if (y == 2'd2) begin ydir <= 1'b1; y <= 2'd1; end
                    else y <= y + 1'b1;
                end else begin
                    if (y == 2'd0) begin ydir <= 1'b0; y <= 2'd1; end
                    else y <= y - 1'b1;
                end
            end

            4'd6: begin
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
            end

            4'd7: begin
                s6 <= {s6[4:0], s6[5]};
                ra <= ({6{s6[0]}} & 6'b101010) | ({6{r6[0]}} & 6'b010101);
                rb <= ({6{s6[1]}} & 6'b101010) | ({6{r6[1]}} & 6'b010101);
                rc <= ({6{s6[2]}} & 6'b101010) | ({6{r6[2]}} & 6'b010101);
                rd <= ({6{s6[3]}} & 6'b101010) | ({6{r6[3]}} & 6'b010101);
                re <= ({6{s6[4]}} & 6'b101010) | ({6{r6[4]}} & 6'b010101);
                rf <= ({6{s6[5]}} & 6'b101010) | ({6{r6[5]}} & 6'b010101);
                lr <= {lr[10:0], lr[11]};
            end

            4'd8: begin
                f6 <= (nst <= 8'd6) ? {f6[4:0], 1'b1} : {f6[4:0], 1'b0};
                set7(f6, f6, f6, f6, f6, f6, f6, 6'b000000);
                lr <= dbl(f6);
            end

            4'd9: begin
                case (nst % 6)
                    8'd0:    begin set7(6'b100001, 6'b100001, 6'b100001, 6'b100001, 6'b100001, 6'b100001, 6'b100001, 6'b000000); lr <= dbl(6'b100001); end
                    8'd1:    begin set7(6'b110011, 6'b110011, 6'b110011, 6'b110011, 6'b110011, 6'b110011, 6'b110011, 6'b000000); lr <= dbl(6'b110011); end
                    8'd2:    begin set7(6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111); lr <= dbl(6'b111111); end
                    8'd3:    begin set7(6'b011110, 6'b011110, 6'b011110, 6'b011110, 6'b011110, 6'b011110, 6'b011110, 6'b000000); lr <= dbl(6'b011110); end
                    8'd4:    begin set7(6'b001100, 6'b001100, 6'b001100, 6'b001100, 6'b001100, 6'b001100, 6'b001100, 6'b000000); lr <= dbl(6'b001100); end
                    default: begin set7(6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000); lr <= 12'b000000000000; end
                endcase
            end

            4'd10: begin
                case (nst % 6)
                    8'd0:    begin set7(6'b001100, 6'b001100, 6'b001100, 6'b001100, 6'b001100, 6'b001100, 6'b001100, 6'b000000); lr <= RED; end
                    8'd2:    begin set7(6'b011110, 6'b011110, 6'b011110, 6'b011110, 6'b011110, 6'b011110, 6'b011110, 6'b000000); lr <= RED | YEL; end
                    default: begin set7(6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000); lr <= 12'b000000000000; end
                endcase
            end

            4'd11: begin
                case (nst % 4)
                    8'd0:    begin set7(6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b001100, 6'b000000); lr <= dbl(6'b001100); end
                    8'd1:    begin set7(6'b011110, 6'b011110, 6'b011110, 6'b011110, 6'b011110, 6'b011110, 6'b011110, 6'b011110); lr <= dbl(6'b011110); end
                    8'd2:    begin set7(6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b000000, 6'b000000); lr <= 12'b111111111111; end
                    default: begin set7(6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000, 6'b000000); lr <= 12'b000000000000; end
                endcase
            end

            4'd12: begin
                ra <= lfsr[5:0]   & lfsr[11:6];
                rb <= lfsr[6:1]   & lfsr[12:7];
                rc <= lfsr[7:2]   & lfsr[13:8];
                rd <= lfsr[8:3]   & lfsr[14:9];
                re <= lfsr[9:4]   & lfsr[15:10];
                rf <= lfsr[10:5]  & lfsr[5:0];
                rg <= lfsr[11:6]  & {lfsr[3:0], 2'b00};
                rp <= lfsr[15:10] & lfsr[9:4];
                lr <= lfsr[11:0];
            end

            default: begin
                case (nst % 3)
                    8'd0:    begin set7(6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111); lr <= 12'b111111111111; end
                    8'd1:    begin set7(6'b101010, 6'b101010, 6'b101010, 6'b101010, 6'b101010, 6'b101010, 6'b010101, 6'b000000); lr <= RED | GRN; end
                    default: begin set7(6'b010101, 6'b010101, 6'b010101, 6'b010101, 6'b010101, 6'b010101, 6'b101010, 6'b000000); lr <= YEL; end
                endcase
            end
        endcase
    end
endtask

always @(posedge clk or negedge reset) begin
    if (!reset) lfsr <= 16'hACE1;
    else        lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
end

always @(posedge clk or negedge reset) begin
    if (!reset) cnt <= 16'd0;
    else        cnt <= cnt + 1'b1;
end

always @(posedge clk or negedge reset) begin
    if (!reset) begin
        sc   <= 4'd0;
        st   <= 8'd0;
        hc   <= 6'd0;
        ctk  <= 26'd0;
        x    <= 6'b100000;
        xp   <= 6'b000000;
        f6   <= 6'b000000;
        s6   <= 6'b000001;
        rpd  <= 6'b111111;
        dir  <= 1'b0;
        ydir <= 1'b0;
        m    <= 1'b0;
        y    <= 2'd0;
        load(4'd0);
    end else begin
        if (ctk >= TICK) begin
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

wire [5:0] A = ra | rr[15:10];
wire [5:0] B = rb | {5'b00000, rr[9]};
wire [5:0] C = rc | {5'b00000, rr[8]};
wire [5:0] D = rd | {rr[2], rr[3], rr[4], rr[5], rr[6], rr[7]};
wire [5:0] E = re | {rr[1], 5'b00000};
wire [5:0] F = rf | {rr[0], 5'b00000};
wire [5:0] G = rg;
wire [5:0] P = rp;

assign led_com = LED_COM;

always @(*) scanout = cnt[15:13];

always @(*) begin
    case (scanout)
        3'd0:    segout = {P[5], G[5], F[5], E[5], D[5], C[5], B[5], A[5]};
        3'd1:    segout = {P[4], G[4], F[4], E[4], D[4], C[4], B[4], A[4]};
        3'd2:    segout = {P[3], G[3], F[3], E[3], D[3], C[3], B[3], A[3]};
        3'd3:    segout = {P[2], G[2], F[2], E[2], D[2], C[2], B[2], A[2]};
        3'd4:    segout = {P[1], G[1], F[1], E[1], D[1], C[1], B[1], A[1]};
        3'd5:    segout = {P[0], G[0], F[0], E[0], D[0], C[0], B[0], A[0]};
        default: segout = 8'b00000000;
    endcase
end

always @(*) led = lr;

endmodule
