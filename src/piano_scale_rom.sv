module piano_scale_rom (
    input  logic [7:0]  address,
    output logic [23:0] data,
    output logic [7:0]  last_address
);

    assign last_address = 8'd255;

    // Use always_comb to ensure combinational logic safety
    always_comb begin
        case (address)
            8'd35:  data = 24'd85522;
            8'd37:  data = 24'd101703;
            8'd38:  data = 24'd128138;
            8'd44:  data = 24'd35958;
            8'd50:  data = 24'd38096;
            8'd51:  data = 24'd42761;
            8'd53:  data = 24'd50852;
            8'd54:  data = 24'd57079;
            8'd55:  data = 24'd64069;
            8'd60:  data = 24'd17979;
            8'd64:  data = 24'd76191;
            8'd66:  data = 24'd13469;
            8'd67:  data = 24'd11326;
            8'd68:  data = 24'd10690;
            8'd69:  data = 24'd90607;
            8'd71:  data = 24'd12713;
            8'd72:  data = 24'd14270;
            8'd73:  data = 24'd143830;
            8'd74:  data = 24'd16017;
            8'd77:  data = 24'd16970;
            8'd78:  data = 24'd15118;
            8'd81:  data = 24'd71915;
            8'd82:  data = 24'd95995;
            8'd83:  data = 24'd9524;
            8'd84:  data = 24'd107751;
            8'd85:  data = 24'd135758;
            8'd86:  data = 24'd11999;
            8'd87:  data = 24'd80722;
            8'd88:  data = 24'd10090;
            8'd89:  data = 24'd120946;
            8'd90:  data = 24'd8989;
            8'd94:  data = 24'd114158;
            8'd98:  data = 24'd26938;
            8'd99:  data = 24'd22652;
            8'd100: data = 24'd21380;
            8'd101: data = 24'd45304;
            8'd103: data = 24'd25426;
            8'd104: data = 24'd28539;
            8'd105: data = 24'd71915;
            8'd106: data = 24'd32035;
            8'd109: data = 24'd33939;
            8'd110: data = 24'd30237;
            8'd113: data = 24'd35958;
            8'd114: data = 24'd47998;
            8'd115: data = 24'd19048;
            8'd116: data = 24'd53756;
            8'd117: data = 24'd67879;
            8'd118: data = 24'd23999;
            8'd119: data = 24'd40361;
            8'd120: data = 24'd20180;
            8'd121: data = 24'd60473;
            8'd122: data = 24'd17979;
            default: data = 24'd0;
        endcase
    end
endmodule