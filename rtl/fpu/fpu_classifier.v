module fpu_classifier
(
    input sign,
    input isSubnormal,
    input isZero,
    input isInf,
    input isNaN,
    input isSignaling,
    output [9:0] masked_out
);


parameter NEG_INF = 10'b00_0000_0001,
          NEG_NORMAL = 10'b00_0000_0010,
          NEG_SUBNORMAL =10'b00_0000_0100,
          NEG_Z   = 10'b00_0000_1000,
          POS_Z = 10'b00_0001_0000,
          POS_SUBNORMAL = 10'b00_0010_0000, 
          POS_NORMAL = 10'b00_0100_0000,
          POS_INF = 10'b00_1000_0000,
          sNaN = 10'b01_0000_0000, 
          qNaN = 10'b10_0000_0000;
   
assign masked_out = isInf       ? (sign         ? NEG_INF       : POS_INF      ):
                    isZero      ? (sign         ? NEG_Z         : POS_Z        ):
                    isNaN       ? (isSignaling  ? sNaN          : qNaN         ):
                    isSubnormal ? (sign         ? NEG_SUBNORMAL : POS_SUBNORMAL):
                                  (sign         ? NEG_NORMAL    : POS_NORMAL   );

endmodule