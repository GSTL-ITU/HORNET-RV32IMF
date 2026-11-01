// FPU testbench: runs every vector of +vectors=<file> through fpu_top (+only=<op> prints that op's failures, +ignore_flags)
`timescale 1ns/1ps

module fpu_tb;

reg clk = 1'b0;
reg rst_n = 1'b0;
always #5 clk = ~clk;

reg         start = 1'b0, kill = 1'b0;
reg  [4:0]  op;
reg  [2:0]  rm;
reg  [31:0] a, b, c;
wire        multi, done;
wire [31:0] result;
wire [4:0]  flags;

fpu_top dut(.clk_i(clk), .rst_ni(rst_n), .start_i(start), .kill_i(kill), .op_i(op), .rm_i(rm),
            .a_i(a), .b_i(b), .c_i(c), .multi_o(multi), .done_o(done), .result_o(result), .flags_o(flags));

string names [0:23] = '{"FADD", "FSUB", "FMUL", "FMADD", "FMSUB", "FNMSUB", "FNMADD", "FDIV", "FSQRT",
                        "FSGNJ", "FSGNJN", "FSGNJX", "FMIN", "FMAX", "FEQ", "FLT", "FLE", "FCLASS",
                        "FMVXW", "FMVWX", "FCVTWS", "FCVTWUS", "FCVTSW", "FCVTSWU"};

initial
begin
    string file;
    int fd, n, errors, shown, max_cycles;
    int count [0:23];
    int fails [0:23];
    int vop, vrm;
    reg [31:0] va, vb, vc, vr;
    reg [4:0]  vf;
    int cyc, only;
    bit no_flags;

    if(!$value$plusargs("vectors=%s", file))
    begin
        $display("no +vectors=<file>");
        $finish;
    end
    fd = $fopen(file, "r");
    for(int i = 0; i < 24; i++) begin count[i] = 0; fails[i] = 0; end
    errors = 0; shown = 0; max_cycles = 0;
    if(!$value$plusargs("only=%d", only)) only = -1;
    no_flags = $test$plusargs("ignore_flags");
    repeat(2) @(posedge clk);
    rst_n <= 1'b1;
    @(posedge clk);
    while($fscanf(fd, "%h %h %h %h %h %h %h", vop, vrm, va, vb, vc, vr, vf) == 7)
    begin
        op = vop; rm = vrm; a = va; b = vb; c = vc;
        #1;
        cyc = 1;
        if(multi)
        begin
            start = 1'b1;
            @(posedge clk); #1;
            start = 1'b0;
            while(!done)
            begin
                @(posedge clk); #1;
                cyc++;
            end
        end
        if(cyc > max_cycles) max_cycles = cyc;
        count[vop]++;
        if(result !== vr || (!no_flags && flags !== vf))
        begin
            errors++;
            fails[vop]++;
            if(shown < 20 && (only < 0 || only == vop))
            begin
                $display("FAIL %s rm=%0d a=%08x b=%08x c=%08x: got %08x/%02x expected %08x/%02x",
                         names[vop], vrm, va, vb, vc, result, flags, vr, vf);
                shown++;
            end
        end
        kill = 1'b1;
        @(posedge clk); #1;
        kill = 1'b0;
    end
    for(int i = 0; i < 24; i++)
        if(count[i] > 0)
            $display("%-8s %8d vectors %8d failures", names[i], count[i], fails[i]);
    if(errors == 0)
        $display("PASS max_cycles=%0d", max_cycles);
    else
        $display("FAIL %0d errors", errors);
    $finish;
end

endmodule
