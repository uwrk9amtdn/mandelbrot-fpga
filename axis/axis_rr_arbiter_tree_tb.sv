module tb;

    localparam int NS   = 33;
    localparam int SANS = 7;

    axis_intf #(8, 1) s [NS] ();
    axis_intf #(8, 1) m ();

    logic clk;
    logic rst;

    axis_rr_arbiter_tree #(
        .NS   (NS),
        .SANS (SANS)
    ) arbiter_tree (
        .clk (clk),
        .rst (rst),

        .s (s),
        .m (m)
    );

    // axis_intf #(8, 1) arbiter_m ();
    // axis_rr_arbiter #(
    //     .NS   (NS)
    // ) arbiter (
    //     .clk (clk),
    //     .rst (rst),

    //     .s (s),
    //     .m (arbiter_m)
    // );

    // axis_skid_buffer sb(clk, rst, arbiter_m, m);

    semaphore sem;
    bit [7:0] q[$][];

    task automatic drive_slave(virtual axis_intf #(8, 1) s []);
        for (int i = 0; i < s.size; i++) begin
            fork
                int j = i;
                repeat (10) begin
                    bit [7:0] d [];
                    int n;
                    n = $urandom % 20;
                    d = new[n];
                    for (int i = 0; i < n; i++) begin
                        repeat ($urandom % 4) @(posedge clk);
                        d[i] = $urandom;
                        s[j].valid <= 1;
                        s[j].data  <= d[i];
                        s[j].last  <= i == n - 1;
                        @(posedge clk iff s[j].valid & s[j].ready);
                        s[j].valid <= 0;
                        // $display("slave_%0d : data = %0d, last = %b", j, s[j].data, s[j].last);
                        if (i == n - 1) begin
                            $display("slave_%0d PACKET : data = %p", j, d);
                        end
                    end
                    sem.get();
                    q.push_back(d);
                    sem.put();
                end
            join_none
        end
        wait fork;
    endtask

    task automatic init_slave(virtual axis_intf #(8, 1) s[]);
        for (int i = 0; i < s.size; i++) begin
            s[i].valid = 0;
        end
    endtask

    task automatic check_master(virtual axis_intf #(8, 1) m);
        bit [7:0] d [$];
        int i [$];
        forever begin
            d = {};
            forever @(posedge clk iff m.ready & m.valid) begin
                // $display("master: data = %0d, last = %b", m.data, m.last);
                d.push_back(m.data);
                if (m.last) begin
                    break;
                end
            end
            $display("master PACKET: data = %p", d);
            #0;
            sem.get();
            i = q.find_first_index() with (item == d);
            if (i.size == 0) begin
                $error("WRONG PACKET RECEIVED");
            end else begin
                $display("CORRECT PACKET RECEIVED");
                q.delete(i[0]);
            end
            sem.put();
        end
    endtask

    initial begin
        sem = new(1);

        clk = 0;
        rst = 1;

        init_slave(s);

        m.ready = 0;

        fork
            forever begin
                #5;
                clk <= ~clk;
            end
            begin
                #20 rst <= 0;
                @(posedge clk);
                drive_slave(s);
                #1us;
                $finish;
            end
            begin
                check_master(m);
            end
            forever begin
                @(posedge clk);
                m.ready <= $urandom;
            end
        join

    end

endmodule