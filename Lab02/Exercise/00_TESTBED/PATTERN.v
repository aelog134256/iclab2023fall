`define CYCLE_TIME 12 //cycle

module PATTERN(
    //Input Port
    clk,
    rst_n,
	in_valid,
	mode,
    xi,
    yi,

    //Output Port
    out_valid,
	xo,
	yo
);


//======================================
//      I/O PORTS
//======================================
output reg   clk, rst_n, in_valid;
output reg   [1:0]   mode;
output reg   [7:0]   xi;
output reg   [7:0]   yi;

input         out_valid;
input [7:0]   xo, yo;

//======================================
//      PARAMETERS & VARIABLES
//======================================
parameter PATNUM = 10;
parameter CYCLE = `CYCLE_TIME;
parameter DELAY = 100;
integer   SEED = 140813;

// PATTERN CONTROL
integer       i;
integer       j;
integer       k;
integer       m;
integer    stop;
integer     pat;
integer pat_prim;
integer exe_lat;
integer out_lat;
integer tot_lat;

// FILE CONTROL
integer file;
integer file_out;

// String control
// Should use %0s
reg[9*8:1]  reset_color       = "\033[1;0m";
reg[10*8:1] txt_black_prefix  = "\033[1;30m";
reg[10*8:1] txt_red_prefix    = "\033[1;31m";
reg[10*8:1] txt_green_prefix  = "\033[1;32m";
reg[10*8:1] txt_yellow_prefix = "\033[1;33m";
reg[10*8:1] txt_blue_prefix   = "\033[1;34m";

reg[10*8:1] bkg_black_prefix  = "\033[40;1m";
reg[10*8:1] bkg_red_prefix    = "\033[41;1m";
reg[10*8:1] bkg_green_prefix  = "\033[42;1m";
reg[10*8:1] bkg_yellow_prefix = "\033[43;1m";
reg[10*8:1] bkg_blue_prefix   = "\033[44;1m";
reg[10*8:1] bkg_white_prefix  = "\033[47;1m";

//======================================
//      DATA MODEL
//======================================
// Parameter
parameter NUM_MODE = 3;
parameter NUM_INPUT_COORD = 4;
parameter SIMPLE_OFFSET = 10;
parameter SIMPLE_MAX = 20;
// Mode 0
parameter MAP_OFFSET = 128; // -128~127 -> 0~255
parameter MAP_LEN  = 2**8; // 2**$size(xi) not support in irun
parameter MAP_NONE = 0;
parameter MAP_MARK = 1;
// Mode 1
integer NO_INTERSECT = {8'h00, 8'h00};
integer IS_INTERSECT = {8'h00, 8'h01};
integer IS_TANGENT   = {8'h00, 8'h02};

// Variable
// 0 : top-left -> top-right -> bottom-left -> bottom-right
// 1 : line point -> center of circle -> point on the circle
// 2 : clock wise
integer _mode;
integer _outputNum;
integer _xin[0:NUM_INPUT_COORD-1];
integer _yin[0:NUM_INPUT_COORD-1];
integer _xgold[0:MAP_LEN*MAP_LEN-1];
integer _ygold[0:MAP_LEN*MAP_LEN-1];
// Mode 0
integer _map[0:MAP_LEN-1][0:MAP_LEN-1];
// Mode 1
integer _radiusSqaure;
integer _distanceNumer; // _distanceNumer/_distanceDenom
integer _distanceDenom;
integer _relation;
// Mode 2
integer _partialProduct[0:NUM_INPUT_COORD-1];
integer _2area;
integer _area;

// Utility
integer item_idx1, item_idx2;
integer y_idx, x_idx;
integer _xtemp;
integer unique_flag;

task reset_data_model; begin
    for(y_idx=0 ; y_idx<MAP_LEN ; y_idx=y_idx+1)begin
        for(x_idx=0 ; x_idx<MAP_LEN ; x_idx=x_idx+1)begin
            _map[y_idx][x_idx] = MAP_NONE;
        end
    end
end endtask

integer temp_x[0:NUM_INPUT_COORD/2-1];
integer temp_y[0:NUM_INPUT_COORD/2-1];
task random_input_simple; begin
    _mode = {$random(SEED)} % NUM_MODE;
    unique_flag = 0;
    while(!unique_flag) begin
        if(_mode == 0) begin
            for(item_idx1=0 ; item_idx1<NUM_INPUT_COORD/2 ; item_idx1=item_idx1+1)begin
                temp_y[item_idx1] = {$random(SEED)}%SIMPLE_MAX - SIMPLE_OFFSET;
            end
            _yin[0] = temp_y[0]>temp_y[1] ? temp_y[0] : temp_y[1];
            _yin[1] = temp_y[0]>temp_y[1] ? temp_y[0] : temp_y[1];
            _yin[2] = temp_y[0]>temp_y[1] ? temp_y[1] : temp_y[0];
            _yin[3] = temp_y[0]>temp_y[1] ? temp_y[1] : temp_y[0];
            // top-left, top-right
            for(item_idx1=0 ; item_idx1<NUM_INPUT_COORD/2 ; item_idx1=item_idx1+1)begin
                temp_x[item_idx1] = {$random(SEED)}%SIMPLE_MAX - SIMPLE_OFFSET;
            end
            _xin[0] = temp_x[0]>temp_x[1] ? temp_x[1] : temp_x[0];
            _xin[1] = temp_x[0]>temp_x[1] ? temp_x[0] : temp_x[1];
            // bottom-left, bottom-right
            for(item_idx1=0 ; item_idx1<NUM_INPUT_COORD/2 ; item_idx1=item_idx1+1)begin
                temp_x[item_idx1] = {$random(SEED)}%SIMPLE_MAX - SIMPLE_OFFSET;
            end
            _xin[2] = temp_x[0]>temp_x[1] ? temp_x[1] : temp_x[0];
            _xin[3] = temp_x[0]>temp_x[1] ? temp_x[0] : temp_x[1];
        end
        if(_mode == 1) begin
            for(item_idx1=0 ; item_idx1<NUM_INPUT_COORD ; item_idx1=item_idx1+1)begin
                _xin[item_idx1] = {$random(SEED)}%SIMPLE_MAX - SIMPLE_OFFSET;
                _yin[item_idx1] = {$random(SEED)}%SIMPLE_MAX - SIMPLE_OFFSET;
            end
        end
        if(_mode == 2) begin
            _xin[0] = {$random(SEED)}%SIMPLE_MAX-1 - SIMPLE_OFFSET;
            _yin[0] = {$random(SEED)}%SIMPLE_MAX-1 - SIMPLE_OFFSET;

            _xin[1] = {$random(SEED)}%(SIMPLE_MAX-_xin[0]-1) + _xin[0] + 1;
            _yin[1] = {$random(SEED)}%(SIMPLE_MAX-_yin[0]-1) + _yin[0] + 1;

            _xin[3] = {$random(SEED)}%(SIMPLE_MAX-_xin[0]-1) + _xin[0] + 1;
            _yin[3] = {$random(SEED)}%(_yin[0]+SIMPLE_OFFSET) - SIMPLE_OFFSET;

            _xin[2] = {$random(SEED)}%(SIMPLE_MAX-_xin[0]-1) + _xin[0] + 1;
            _yin[2] = {$random(SEED)}%(_yin[1]-_yin[3]) + _yin[3];
        end
        check_unique;
    end
end endtask
task random_input; begin
    _mode = {$random(SEED)} % NUM_MODE;
    unique_flag = 0;
    while(!unique_flag) begin
        if(_mode == 0) begin
            for(item_idx1=0 ; item_idx1<NUM_INPUT_COORD/2 ; item_idx1=item_idx1+1)begin
                temp_y[item_idx1] = {$random(SEED)}%MAP_LEN - MAP_OFFSET;
            end
            _yin[0] = temp_y[0]>temp_y[1] ? temp_y[0] : temp_y[1];
            _yin[1] = temp_y[0]>temp_y[1] ? temp_y[0] : temp_y[1];
            _yin[2] = temp_y[0]>temp_y[1] ? temp_y[1] : temp_y[0];
            _yin[3] = temp_y[0]>temp_y[1] ? temp_y[1] : temp_y[0];
            // top-left, top-right
            for(item_idx1=0 ; item_idx1<NUM_INPUT_COORD/2 ; item_idx1=item_idx1+1)begin
                temp_x[item_idx1] = {$random(SEED)}%MAP_LEN - MAP_OFFSET;
            end
            _xin[0] = temp_x[0]>temp_x[1] ? temp_x[1] : temp_x[0];
            _xin[1] = temp_x[0]>temp_x[1] ? temp_x[0] : temp_x[1];
            // bottom-left, bottom-right
            for(item_idx1=0 ; item_idx1<NUM_INPUT_COORD/2 ; item_idx1=item_idx1+1)begin
                temp_x[item_idx1] = {$random(SEED)}%MAP_LEN - MAP_OFFSET;
            end
            _xin[2] = temp_x[0]>temp_x[1] ? temp_x[1] : temp_x[0];
            _xin[3] = temp_x[0]>temp_x[1] ? temp_x[0] : temp_x[1];
        end
        if(_mode == 1) begin
            for(item_idx1=0 ; item_idx1<NUM_INPUT_COORD ; item_idx1=item_idx1+1)begin
                _xin[item_idx1] = {$random(SEED)}%MAP_LEN - MAP_OFFSET;
                _yin[item_idx1] = {$random(SEED)}%MAP_LEN - MAP_OFFSET;
            end
        end
        if(_mode == 2) begin
            _xin[0] = {$random(SEED)}%MAP_LEN-1 - MAP_OFFSET;
            _yin[0] = {$random(SEED)}%MAP_LEN-1 - MAP_OFFSET;

            _xin[1] = {$random(SEED)}%(MAP_LEN-_xin[0]-1) + _xin[0] + 1;
            _yin[1] = {$random(SEED)}%(MAP_LEN-_yin[0]-1) + _yin[0] + 1;

            _xin[3] = {$random(SEED)}%(MAP_LEN-_xin[0]-1) + _xin[0] + 1;
            _yin[3] = {$random(SEED)}%(_yin[0]+MAP_OFFSET) - MAP_OFFSET;

            _xin[2] = {$random(SEED)}%(MAP_LEN-_xin[0]-1) + _xin[0] + 1;
            _yin[2] = {$random(SEED)}%(_yin[1]-_yin[3]) + _yin[3];
        end
        check_unique;
    end
end endtask

task check_unique; begin
    unique_flag = 1;
    // Four point unique
    for(item_idx1=0 ; item_idx1<NUM_INPUT_COORD ; item_idx1=item_idx1+1)begin
        for(item_idx2=item_idx1+1 ; item_idx2<NUM_INPUT_COORD ; item_idx2=item_idx2+1)begin
            if(_xin[item_idx1] === _xin[item_idx2] && _yin[item_idx1] === _yin[item_idx2])
                unique_flag = 0;
        end
    end
    // Mode 0
    // Check y axis
    if(_mode === 0 && _yin[0] == _yin[2])
        unique_flag = 0;
end endtask

task run_mode0; begin

end endtask

task run_mode1; begin
    _radiusSqaure = (_xin[2]-_xin[3])*(_xin[2]-_xin[3]) + (_yin[2]-_yin[3])*(_yin[2]-_yin[3]);
    _distanceNumer = (_yin[0]-_yin[1])*(_xin[2]-_xin[0]) - (_xin[0]-_xin[1])*(_yin[2]-_yin[0]);
    _distanceNumer = _distanceNumer * _distanceNumer;
    _distanceDenom = (_xin[0]-_xin[1])*(_xin[0]-_xin[1]) + (_yin[0]-_yin[1])*(_yin[0]-_yin[1]);
    if(_distanceNumer === _distanceDenom*_radiusSqaure) begin
        _relation = IS_TANGENT;
    end
    if(_distanceNumer > _distanceDenom*_radiusSqaure) begin
        _relation = NO_INTERSECT;
    end
    if(_distanceNumer < _distanceDenom*_radiusSqaure) begin
        _relation = IS_INTERSECT;
    end
    _outputNum = 1;
    _xgold = 0;
    _ygold = _relation;
end endtask

task run_mode2; begin
    _2area = 0;
    for(item_idx1=0 ; item_idx1<NUM_INPUT_COORD ; item_idx1=item_idx1+1)begin
        if(item_idx1+1==NUM_INPUT_COORD)
            _partialProduct[item_idx1] = _xin[item_idx1]*_yin[0] - _xin[0]*_yin[item_idx1];
        else
            _partialProduct[item_idx1] = _xin[item_idx1]*_yin[item_idx1+1] - _xin[item_idx1+1]*_yin[item_idx1];
        _2area = _2area - _partialProduct[item_idx1];
    end 
    _area = _2area/2;
    _outputNum = 1;
    {_xgold, _ygold} = _area;
end endtask

task report_setting; begin
    $display("[=================================]");
    $display("[ Parameter Info ]", pat);
    $display("[ NUM_MODE        : %-1d ]", NUM_MODE);
    $display("[ NUM_INPUT_COORD : %-1d ]", NUM_INPUT_COORD);

    $display("[ MAP_LEN  : %-1d ]", MAP_LEN );
    $display("[ MAP_NONE : %-1d ]", MAP_NONE);
    $display("[ MAP_MARK : %-1d ]", MAP_MARK);

    $display("[ NO_INTERSECT : %-2h ]", NO_INTERSECT);
    $display("[ IS_INTERSECT : %-2h ]", IS_INTERSECT);
    $display("[ IS_TANGENT   : %-2h ]", IS_TANGENT );
    $display("[=================================]");
end endtask

task report_input; begin
    $display("[=================================]");
    $display("[ Input Info ]");
    $display("[ Pattern #%6d ]", pat);
    $display("[ Mode : %-1d ]", _mode);
    $display("[ Input coordinate : ]");
    for(item_idx1=0 ; item_idx1<NUM_INPUT_COORD ; item_idx1=item_idx1+1)begin
        $display("    ( X, Y ) = ( %-4d, %-4d )", _xin[item_idx1], _yin[item_idx1]);
    end
    $display("[=================================]");
end endtask

task report_calculate; begin
    $display("[=================================]");
    if(_mode == 1) begin
        $display("[ Mode 1 ]");
        $display("[ Radius^2 : %-1d]", _radiusSqaure);
        $display("[ Distance^2 ]");
        $display("    Numerator    : %-1d", _distanceNumer);
        $display("    Denominator  : %-1d", _distanceDenom);
        $display("[ Ralation : %4h ]", _relation);
        if(_relation == 'h0000) $display("----> Non-Intersect ");
        if(_relation == 'h0001) $display("----> Intersect ");
        if(_relation == 'h0002) $display("----> Tagent ");
    end
    if(_mode == 2) begin
        $display("[ Mode 2 Partial product ]");
        $display("[ Clockwise ]");
        for(item_idx1=0 ; item_idx1<NUM_INPUT_COORD ; item_idx1=item_idx1+1)begin
            $display("    #%-1d ( X, Y ) = ( %-4d, %-4d )", item_idx1, _xin[item_idx1], _yin[item_idx1]);
        end
        for(item_idx1=0 ; item_idx1<NUM_INPUT_COORD ; item_idx1=item_idx1+1)begin
            if(item_idx1+1==NUM_INPUT_COORD)
                $display("    #%-1d - #%-1d Inner Product : %-1d", item_idx1, 0, _partialProduct[item_idx1]);
            else
                $display("    #%-1d - #%-1d Inner Product : %-1d", item_idx1, item_idx1+1, _partialProduct[item_idx1]);
        end
        $display("[ Area*2 : %-1d]", _2area);
        $display("[ Area   : %-1d]", _area);
    end
    $display("[=================================]");
end endtask

task report_output; begin
    $display("[=================================]");
    $display("[ Your Output ]");
    $display("[ X : %-1d ]", xo);
    $display("[ Y : %-1d ]", yo);
    $display("[=================================]");
end endtask

//======================================
//              MAIN
//======================================
initial exe_task;

//======================================
//              Clock
//======================================
initial clk = 1'b0;
always #(CYCLE/2.0) clk = ~clk;

//======================================
//              TASKS
//======================================
task exe_task; begin
    reset_task;
    for (pat=0 ; pat<PATNUM ; pat=pat+1) begin
        input_task;
        calculate_task;
        wait_task;
        check_task;
    end
    // pass_task;
    $finish;
end endtask

//**************************************
//      Reset Task
//**************************************
task reset_task; begin

    force clk = 0;
    rst_n     = 1;
	mode      = 'dx;
	xi        = 'dx;
	yi        = 'dx;


    #(CYCLE/2.0) rst_n = 0;
    #(CYCLE/2.0) rst_n = 1;
    if(out_valid !== 0 || xo !== 0 || yo !== 0) begin
        $display("                                           `:::::`                                                       ");
        $display("                                          .+-----++                                                      ");
        $display("                .--.`                    o:------/o                                                      ");
        $display("              /+:--:o/                   //-------y.          -//:::-        `.`                         ");
        $display("            `/:------y:                  `o:--::::s/..``    `/:-----s-    .:/:::+:                       ");
        $display("            +:-------:y                `.-:+///::-::::://:-.o-------:o  `/:------s-                      ");
        $display("            y---------y-        ..--:::::------------------+/-------/+ `+:-------/s                      ");
        $display("           `s---------/s       +:/++/----------------------/+-------s.`o:--------/s                      ");
        $display("           .s----------y-      o-:----:---------------------/------o: +:---------o:                      ");
        $display("           `y----------:y      /:----:/-------/o+----------------:+- //----------y`                      ");
        $display("            y-----------o/ `.--+--/:-/+--------:+o--------------:o: :+----------/o                       ");
        $display("            s:----------:y/-::::::my-/:----------/---------------+:-o-----------y.                       ");
        $display("            -o----------s/-:hmmdy/o+/:---------------------------++o-----------/o                        ");
        $display("             s:--------/o--hMMMMMh---------:ho-------------------yo-----------:s`                        ");
        $display("             :o--------s/--hMMMMNs---------:hs------------------+s------------s-                         ");
        $display("              y:-------o+--oyhyo/-----------------------------:o+------------o-                          ");
        $display("              -o-------:y--/s--------------------------------/o:------------o/                           ");
        $display("               +/-------o+--++-----------:+/---------------:o/-------------+/                            ");
        $display("               `o:-------s:--/+:-------/o+-:------------::+d:-------------o/                             ");
        $display("                `o-------:s:---ohsoosyhh+----------:/+ooyhhh-------------o:                              ");
        $display("                 .o-------/d/--:h++ohy/---------:osyyyyhhyyd-----------:o-                               ");
        $display("                 .dy::/+syhhh+-::/::---------/osyyysyhhysssd+---------/o`                                ");
        $display("                  /shhyyyymhyys://-------:/oyyysyhyydysssssyho-------od:                                 ");
        $display("                    `:hhysymmhyhs/:://+osyyssssydyydyssssssssyyo+//+ymo`                                 ");
        $display("                      `+hyydyhdyyyyyyyyyyssssshhsshyssssssssssssyyyo:`                                   ");
        $display("                        -shdssyyyyyhhhhhyssssyyssshssssssssssssyy+.    Output signal should be 0         ");
        $display("                         `hysssyyyysssssssssssssssyssssssssssshh+                                        ");
        $display("                        :yysssssssssssssssssssssssssssssssssyhysh-     after the reset signal is asserted");
        $display("                      .yyhhdo++oosyyyyssssssssssssssssssssssyyssyh/                                      ");
        $display("                      .dhyh/--------/+oyyyssssssssssssssssssssssssy:   at %4d ps                         ", $time*1000);
        $display("                       .+h/-------------:/osyyysssssssssssssssyyh/.                                      ");
        $display("                        :+------------------::+oossyyyyyyyysso+/s-                                       ");
        $display("                       `s--------------------------::::::::-----:o                                       ");
        $display("                       +:----------------------------------------y`                                      ");
        repeat(5) #(CYCLE);
        $finish;
    end
    #(CYCLE/2.0) release clk;
end endtask

//**************************************
//      Input Task
//**************************************
task input_task; begin
    if(pat < 20) random_input_simple;
    else random_input;
    repeat(({$random(SEED)} % 4 + 2)) @(negedge clk);
    for(item_idx1=0 ; item_idx1<NUM_INPUT_COORD ; item_idx1=item_idx1+1)begin
        in_valid = 1;
        mode = _mode;
        xi = _xin[item_idx1];
        yi = _yin[item_idx1];
        @(negedge clk);
    end
    in_valid = 0;
    mode = 0;
    xi = 'dx;
    yi = 'dx;
end endtask

//**************************************
//      Calculate Task
//**************************************
task calculate_task; begin
    if(_mode == 0) begin
        run_mode0;
    end
    if(_mode == 1) begin
        run_mode1;
    end
    if(_mode == 2) begin
        run_mode2;
    end
    report_calculate;
end endtask

//**************************************
//      Wait Task
//**************************************
task wait_task; begin
    exe_lat = -1;
    while(out_valid !== 1) begin
        if(xo !== 0 || yo !== 0) begin
            $display("                                           `:::::`                                                       ");
            $display("                                          .+-----++                                                      ");
            $display("                .--.`                    o:------/o                                                      ");
            $display("              /+:--:o/                   //-------y.          -//:::-        `.`                         ");
            $display("            `/:------y:                  `o:--::::s/..``    `/:-----s-    .:/:::+:                       ");
            $display("            +:-------:y                `.-:+///::-::::://:-.o-------:o  `/:------s-                      ");
            $display("            y---------y-        ..--:::::------------------+/-------/+ `+:-------/s                      ");
            $display("           `s---------/s       +:/++/----------------------/+-------s.`o:--------/s                      ");
            $display("           .s----------y-      o-:----:---------------------/------o: +:---------o:                      ");
            $display("           `y----------:y      /:----:/-------/o+----------------:+- //----------y`                      ");
            $display("            y-----------o/ `.--+--/:-/+--------:+o--------------:o: :+----------/o                       ");
            $display("            s:----------:y/-::::::my-/:----------/---------------+:-o-----------y.                       ");
            $display("            -o----------s/-:hmmdy/o+/:---------------------------++o-----------/o                        ");
            $display("             s:--------/o--hMMMMMh---------:ho-------------------yo-----------:s`                        ");
            $display("             :o--------s/--hMMMMNs---------:hs------------------+s------------s-                         ");
            $display("              y:-------o+--oyhyo/-----------------------------:o+------------o-                          ");
            $display("              -o-------:y--/s--------------------------------/o:------------o/                           ");
            $display("               +/-------o+--++-----------:+/---------------:o/-------------+/                            ");
            $display("               `o:-------s:--/+:-------/o+-:------------::+d:-------------o/                             ");
            $display("                `o-------:s:---ohsoosyhh+----------:/+ooyhhh-------------o:                              ");
            $display("                 .o-------/d/--:h++ohy/---------:osyyyyhhyyd-----------:o-                               ");
            $display("                 .dy::/+syhhh+-::/::---------/osyyysyhhysssd+---------/o`                                ");
            $display("                  /shhyyyymhyys://-------:/oyyysyhyydysssssyho-------od:                                 ");
            $display("                    `:hhysymmhyhs/:://+osyyssssydyydyssssssssyyo+//+ymo`                                 ");
            $display("                      `+hyydyhdyyyyyyyyyyssssshhsshyssssssssssssyyyo:`                                   ");
            $display("                        -shdssyyyyyhhhhhyssssyyssshssssssssssssyy+.    Output signal should be 0         ");
            $display("                         `hysssyyyysssssssssssssssyssssssssssshh+                                        ");
            $display("                        :yysssssssssssssssssssssssssssssssssyhysh-     when the out_valid is pulled down ");
            $display("                      .yyhhdo++oosyyyyssssssssssssssssssssssyyssyh/                                      ");
            $display("                      .dhyh/--------/+oyyyssssssssssssssssssssssssy:   at %4d ps                         ", $time*1000);
            $display("                       .+h/-------------:/osyyysssssssssssssssyyh/.                                      ");
            $display("                        :+------------------::+oossyyyyyyyysso+/s-                                       ");
            $display("                       `s--------------------------::::::::-----:o                                       ");
            $display("                       +:----------------------------------------y`                                      ");
            repeat(5) #(CYCLE);
            $finish;
        end
        if (exe_lat == DELAY) begin
            $display("                                   ..--.                                ");
            $display("                                `:/:-:::/-                              ");
            $display("                                `/:-------o                             ");
            $display("                                /-------:o:                             "); 
            $display("                                +-:////+s/::--..                        ");
            $display("    The execution latency      .o+/:::::----::::/:-.       at %-12d ps  ", $time*1000);
            $display("    is over %5d   cycles    `:::--:/++:----------::/:.                ", DELAY);
            $display("                            -+:--:++////-------------::/-               ");
            $display("                            .+---------------------------:/--::::::.`   ");
            $display("                          `.+-----------------------------:o/------::.  ");
            $display("                       .-::-----------------------------:--:o:-------:  ");
            $display("                     -:::--------:/yy------------------/y/--/o------/-  ");
            $display("                    /:-----------:+y+:://:--------------+y--:o//:://-   ");
            $display("                   //--------------:-:+ssoo+/------------s--/. ````     ");
            $display("                   o---------:/:------dNNNmds+:----------/-//           ");
            $display("                   s--------/o+:------yNNNNNd/+--+y:------/+            ");
            $display("                 .-y---------o:-------:+sso+/-:-:yy:------o`            ");
            $display("              `:oosh/--------++-----------------:--:------/.            ");
            $display("              +ssssyy--------:y:---------------------------/            ");
            $display("              +ssssyd/--------/s/-------------++-----------/`           ");
            $display("              `/yyssyso/:------:+o/::----:::/+//:----------+`           ");
            $display("             ./osyyyysssso/------:/++o+++///:-------------/:            ");
            $display("           -osssssssssssssso/---------------------------:/.             ");
            $display("         `/sssshyssssssssssss+:---------------------:/+ss               ");
            $display("        ./ssssyysssssssssssssso:--------------:::/+syyys+               ");
            $display("     `-+sssssyssssssssssssssssso-----::/++ooooossyyssyy:                ");
            $display("     -syssssyssssssssssssssssssso::+ossssssssssssyyyyyss+`              ");
            $display("     .hsyssyssssssssssssssssssssyssssssssssyhhhdhhsssyssso`             ");
            $display("     +/yyshsssssssssssssssssssysssssssssyhhyyyyssssshysssso             ");
            $display("    ./-:+hsssssssssssssssssssssyyyyyssssssssssssssssshsssss:`           ");
            $display("    /---:hsyysyssssssssssssssssssssssssssssssssssssssshssssy+           ");
            $display("    o----oyy:-:/+oyysssssssssssssssssssssssssssssssssshssssy+-          ");
            $display("    s-----++-------/+sysssssssssssssssssssssssssssssyssssyo:-:-         ");
            $display("    o/----s-----------:+syyssssssssssssssssssssssyso:--os:----/.        ");
            $display("    `o/--:o---------------:+ossyysssssssssssyyso+:------o:-----:        ");
            $display("      /+:/+---------------------:/++ooooo++/:------------s:---::        ");
            $display("       `/o+----------------------------------------------:o---+`        ");
            $display("         `+-----------------------------------------------o::+.         ");
            $display("          +-----------------------------------------------/o/`          ");
            $display("          ::----------------------------------------------:-            ");
            repeat(5) @(negedge clk);
            $finish; 
        end
        exe_lat = exe_lat + 1;
        @(negedge clk);
    end
end endtask

//**************************************
//      Check Task
//**************************************
task check_task; begin
    out_lat = 0;
    while(out_valid === 1) begin
        if(out_lat == _outputNum) begin
            $display("                                                                                ");
            $display("                                                   ./+oo+/.                     ");
            $display("    Out cycles is more than %-2d                    /s:-----+s`     at %-12d ps ", _outputNum, $time*1000);
            $display("                                                  y/-------:y                   ");
            $display("                                             `.-:/od+/------y`                  ");
            $display("                               `:///+++ooooooo+//::::-----:/y+:`                ");
            $display("                              -m+:::::::---------------------::o+.              ");
            $display("                             `hod-------------------------------:o+             ");
            $display("                       ./++/:s/-o/--------------------------------/s///::.      ");
            $display("                      /s::-://--:--------------------------------:oo/::::o+     ");
            $display("                    -+ho++++//hh:-------------------------------:s:-------+/    ");
            $display("                  -s+shdh+::+hm+--------------------------------+/--------:s    ");
            $display("                 -s:hMMMMNy---+y/-------------------------------:---------//    ");
            $display("                 y:/NMMMMMN:---:s-/o:-------------------------------------+`    ");
            $display("                 h--sdmmdy/-------:hyssoo++:----------------------------:/`     ");
            $display("                 h---::::----------+oo+/::/+o:---------------------:+++s-`      ");
            $display("                 s:----------------/s+///------------------------------o`       ");
            $display("           ``..../s------------------::--------------------------------o        ");
            $display("       -/oyhyyyyyym:----------------://////:--------------------------:/        ");
            $display("      /dyssyyyssssyh:-------------/o+/::::/+o/------------------------+`        ");
            $display("    -+o/---:/oyyssshd/-----------+o:--------:oo---------------------:/.         ");
            $display("  `++--------:/sysssddy+:-------/+------------s/------------------://`          ");
            $display(" .s:---------:+ooyysyyddoo++os-:s-------------/y----------------:++.            ");
            $display(" s:------------/yyhssyshy:---/:o:-------------:dsoo++//:::::-::+syh`            ");
            $display("`h--------------shyssssyyms+oyo:--------------/hyyyyyyyyyyyysyhyyyy`            ");
            $display("`h--------------:yyssssyyhhyy+----------------+dyyyysssssssyyyhs+/.             ");
            $display(" s:--------------/yysssssyhy:-----------------shyyyyyhyyssssyyh.                ");
            $display(" .s---------------+sooosyyo------------------/yssssssyyyyssssyo                 ");
            $display("  /+-------------------:++------------------:ysssssssssssssssy-                 ");
            $display("  `s+--------------------------------------:syssssssssssssssyo                  ");
            $display("`+yhdo--------------------:/--------------:syssssssssssssssyy.                  ");
            $display("+yysyhh:-------------------+o------------/ysyssssssssssssssy/                   ");
            $display(" /hhysyds:------------------y-----------/+yyssssssssssssssyh`                   ");
            $display(" .h-+yysyds:---------------:s----------:--/yssssssssssssssym:                   ");
            $display(" y/---oyyyyhyo:-----------:o:-------------:ysssssssssyyyssyyd-                  ");
            $display("`h------+syyyyhhsoo+///+osh---------------:ysssyysyyyyysssssyd:                 ");
            $display("/s--------:+syyyyyyyyyyyyyyhso/:-------::+oyyyyhyyyysssssssyy+-                 ");
            $display("+s-----------:/osyyysssssssyyyyhyyyyyyyydhyyyyyyssssssssyys/`                   ");
            $display("+s---------------:/osyyyysssssssssssssssyyhyyssssssyyyyso/y`                    ");
            $display("/s--------------------:/+ossyyyyyyssssssssyyyyyyysso+:----:+                    ");
            $display(".h--------------------------:::/++oooooooo+++/:::----------o`                   ");
            repeat(5) @(negedge clk);
            $finish;
        end
        //====================
        // Check
        //====================
        // TODO
        // mode 0 => use map to check
        if((xo !== _xgold || yo !== _ygold) && mode !== 0) begin
            $display("                                                                                ");
            $display("                                                   ./+oo+/.                     ");
            $display("    Output is not correct!!!                      /s:-----+s`     at %-12d ps   ", $time*1000);
            $display("                                                  y/-------:y                   ");
            $display("                                             `.-:/od+/------y`                  ");
            $display("                               `:///+++ooooooo+//::::-----:/y+:`                ");
            $display("                              -m+:::::::---------------------::o+.              ");
            $display("                             `hod-------------------------------:o+             ");
            $display("                       ./++/:s/-o/--------------------------------/s///::.      ");
            $display("                      /s::-://--:--------------------------------:oo/::::o+     ");
            $display("                    -+ho++++//hh:-------------------------------:s:-------+/    ");
            $display("                  -s+shdh+::+hm+--------------------------------+/--------:s    ");
            $display("                 -s:hMMMMNy---+y/-------------------------------:---------//    ");
            $display("                 y:/NMMMMMN:---:s-/o:-------------------------------------+`    ");
            $display("                 h--sdmmdy/-------:hyssoo++:----------------------------:/`     ");
            $display("                 h---::::----------+oo+/::/+o:---------------------:+++s-`      ");
            $display("                 s:----------------/s+///------------------------------o`       ");
            $display("           ``..../s------------------::--------------------------------o        ");
            $display("       -/oyhyyyyyym:----------------://////:--------------------------:/        ");
            $display("      /dyssyyyssssyh:-------------/o+/::::/+o/------------------------+`        ");
            $display("    -+o/---:/oyyssshd/-----------+o:--------:oo---------------------:/.         ");
            $display("  `++--------:/sysssddy+:-------/+------------s/------------------://`          ");
            $display(" .s:---------:+ooyysyyddoo++os-:s-------------/y----------------:++.            ");
            $display(" s:------------/yyhssyshy:---/:o:-------------:dsoo++//:::::-::+syh`            ");
            $display("`h--------------shyssssyyms+oyo:--------------/hyyyyyyyyyyyysyhyyyy`            ");
            $display("`h--------------:yyssssyyhhyy+----------------+dyyyysssssssyyyhs+/.             ");
            $display(" s:--------------/yysssssyhy:-----------------shyyyyyhyyssssyyh.                ");
            $display(" .s---------------+sooosyyo------------------/yssssssyyyyssssyo                 ");
            $display("  /+-------------------:++------------------:ysssssssssssssssy-                 ");
            $display("  `s+--------------------------------------:syssssssssssssssyo                  ");
            $display("`+yhdo--------------------:/--------------:syssssssssssssssyy.                  ");
            $display("+yysyhh:-------------------+o------------/ysyssssssssssssssy/                   ");
            $display(" /hhysyds:------------------y-----------/+yyssssssssssssssyh`                   ");
            $display(" .h-+yysyds:---------------:s----------:--/yssssssssssssssym:                   ");
            $display(" y/---oyyyyhyo:-----------:o:-------------:ysssssssssyyyssyyd-                  ");
            $display("`h------+syyyyhhsoo+///+osh---------------:ysssyysyyyyysssssyd:                 ");
            $display("/s--------:+syyyyyyyyyyyyyyhso/:-------::+oyyyyhyyyysssssssyy+-                 ");
            $display("+s-----------:/osyyysssssssyyyyhyyyyyyyydhyyyyyyssssssssyys/`                   ");
            $display("+s---------------:/osyyyysssssssssssssssyyhyyssssssyyyyso/y`                    ");
            $display("/s--------------------:/+ossyyyyyyssssssssyyyyyyysso+:----:+                    ");
            $display(".h--------------------------:::/++oooooooo+++/:::----------o`                   "); 
            report_input;
            report_calculate;
            report_output;
            repeat(5) @(negedge clk);
            $finish;
        end

        out_lat = out_lat + 1;
        @(negedge clk);
    end

    if (out_lat<_outputNum) begin     
        $display("                                                                                ");
        $display("                                                   ./+oo+/.                     ");
        $display("    Out cycles is less than %-2d                    /s:-----+s`     at %-12d ps ", _outputNum, $time*1000);
        $display("                                                  y/-------:y                   ");
        $display("                                             `.-:/od+/------y`                  ");
        $display("                               `:///+++ooooooo+//::::-----:/y+:`                ");
        $display("                              -m+:::::::---------------------::o+.              ");
        $display("                             `hod-------------------------------:o+             ");
        $display("                       ./++/:s/-o/--------------------------------/s///::.      ");
        $display("                      /s::-://--:--------------------------------:oo/::::o+     ");
        $display("                    -+ho++++//hh:-------------------------------:s:-------+/    ");
        $display("                  -s+shdh+::+hm+--------------------------------+/--------:s    ");
        $display("                 -s:hMMMMNy---+y/-------------------------------:---------//    ");
        $display("                 y:/NMMMMMN:---:s-/o:-------------------------------------+`    ");
        $display("                 h--sdmmdy/-------:hyssoo++:----------------------------:/`     ");
        $display("                 h---::::----------+oo+/::/+o:---------------------:+++s-`      ");
        $display("                 s:----------------/s+///------------------------------o`       ");
        $display("           ``..../s------------------::--------------------------------o        ");
        $display("       -/oyhyyyyyym:----------------://////:--------------------------:/        ");
        $display("      /dyssyyyssssyh:-------------/o+/::::/+o/------------------------+`        ");
        $display("    -+o/---:/oyyssshd/-----------+o:--------:oo---------------------:/.         ");
        $display("  `++--------:/sysssddy+:-------/+------------s/------------------://`          ");
        $display(" .s:---------:+ooyysyyddoo++os-:s-------------/y----------------:++.            ");
        $display(" s:------------/yyhssyshy:---/:o:-------------:dsoo++//:::::-::+syh`            ");
        $display("`h--------------shyssssyyms+oyo:--------------/hyyyyyyyyyyyysyhyyyy`            ");
        $display("`h--------------:yyssssyyhhyy+----------------+dyyyysssssssyyyhs+/.             ");
        $display(" s:--------------/yysssssyhy:-----------------shyyyyyhyyssssyyh.                ");
        $display(" .s---------------+sooosyyo------------------/yssssssyyyyssssyo                 ");
        $display("  /+-------------------:++------------------:ysssssssssssssssy-                 ");
        $display("  `s+--------------------------------------:syssssssssssssssyo                  ");
        $display("`+yhdo--------------------:/--------------:syssssssssssssssyy.                  ");
        $display("+yysyhh:-------------------+o------------/ysyssssssssssssssy/                   ");
        $display(" /hhysyds:------------------y-----------/+yyssssssssssssssyh`                   ");
        $display(" .h-+yysyds:---------------:s----------:--/yssssssssssssssym:                   ");
        $display(" y/---oyyyyhyo:-----------:o:-------------:ysssssssssyyyssyyd-                  ");
        $display("`h------+syyyyhhsoo+///+osh---------------:ysssyysyyyyysssssyd:                 ");
        $display("/s--------:+syyyyyyyyyyyyyyhso/:-------::+oyyyyhyyyysssssssyy+-                 ");
        $display("+s-----------:/osyyysssssssyyyyhyyyyyyyydhyyyyyyssssssssyys/`                   ");
        $display("+s---------------:/osyyyysssssssssssssssyyhyyssssssyyyyso/y`                    ");
        $display("/s--------------------:/+ossyyyyyyssssssssyyyyyyysso+:----:+                    ");
        $display(".h--------------------------:::/++oooooooo+++/:::----------o`                   "); 
        repeat(5) @(negedge clk);
        $finish;
    end
    tot_lat = tot_lat + exe_lat;
end endtask

//**************************************
//      PASS Task
//**************************************
task pass_task; begin
    $display("\033[1;33m                `oo+oy+`                            \033[1;35m Congratulation!!! \033[1;0m                                   ");
    $display("\033[1;33m               /h/----+y        `+++++:             \033[1;35m PASS This Lab........Maybe \033[1;0m                          ");
    $display("\033[1;33m             .y------:m/+ydoo+:y:---:+o             \033[1;35m Total Latency : %-10d\033[1;0m                                ", tot_lat);
    $display("\033[1;33m              o+------/y--::::::+oso+:/y                                                                                     ");
    $display("\033[1;33m              s/-----:/:----------:+ooy+-                                                                                    ");
    $display("\033[1;33m             /o----------------/yhyo/::/o+/:-.`                                                                              ");
    $display("\033[1;33m            `ys----------------:::--------:::+yyo+                                                                           ");
    $display("\033[1;33m            .d/:-------------------:--------/--/hos/                                                                         ");
    $display("\033[1;33m            y/-------------------::ds------:s:/-:sy-                                                                         ");
    $display("\033[1;33m           +y--------------------::os:-----:ssm/o+`                                                                          ");
    $display("\033[1;33m          `d:-----------------------:-----/+o++yNNmms                                                                        ");
    $display("\033[1;33m           /y-----------------------------------hMMMMN.                                                                      ");
    $display("\033[1;33m           o+---------------------://:----------:odmdy/+.                                                                    ");
    $display("\033[1;33m           o+---------------------::y:------------::+o-/h                                                                    ");
    $display("\033[1;33m           :y-----------------------+s:------------/h:-:d                                                                    ");
    $display("\033[1;33m           `m/-----------------------+y/---------:oy:--/y                                                                    ");
    $display("\033[1;33m            /h------------------------:os++/:::/+o/:--:h-                                                                    ");
    $display("\033[1;33m         `:+ym--------------------------://++++o/:---:h/                                                                     ");
    $display("\033[1;31m        `hhhhhoooo++oo+/:\033[1;33m--------------------:oo----\033[1;31m+dd+                                                 ");
    $display("\033[1;31m         shyyyhhhhhhhhhhhso/:\033[1;33m---------------:+/---\033[1;31m/ydyyhs:`                                              ");
    $display("\033[1;31m         .mhyyyyyyhhhdddhhhhhs+:\033[1;33m----------------\033[1;31m:sdmhyyyyyyo:                                            ");
    $display("\033[1;31m        `hhdhhyyyyhhhhhddddhyyyyyo++/:\033[1;33m--------\033[1;31m:odmyhmhhyyyyhy                                            ");
    $display("\033[1;31m        -dyyhhyyyyyyhdhyhhddhhyyyyyhhhs+/::\033[1;33m-\033[1;31m:ohdmhdhhhdmdhdmy:                                           ");
    $display("\033[1;31m         hhdhyyyyyyyyyddyyyyhdddhhyyyyyhhhyyhdhdyyhyys+ossyhssy:-`                                                           ");
    $display("\033[1;31m         `Ndyyyyyyyyyyymdyyyyyyyhddddhhhyhhhhhhhhy+/:\033[1;33m-------::/+o++++-`                                            ");
    $display("\033[1;31m          dyyyyyyyyyyyyhNyydyyyyyyyyyyhhhhyyhhy+/\033[1;33m------------------:/ooo:`                                         ");
    $display("\033[1;31m         :myyyyyyyyyyyyyNyhmhhhyyyyyhdhyyyhho/\033[1;33m-------------------------:+o/`                                       ");
    $display("\033[1;31m        /dyyyyyyyyyyyyyyddmmhyyyyyyhhyyyhh+:\033[1;33m-----------------------------:+s-                                      ");
    $display("\033[1;31m      +dyyyyyyyyyyyyyyydmyyyyyyyyyyyyyds:\033[1;33m---------------------------------:s+                                      ");
    $display("\033[1;31m      -ddhhyyyyyyyyyyyyyddyyyyyyyyyyyhd+\033[1;33m------------------------------------:oo              `-++o+:.`             ");
    $display("\033[1;31m       `/dhshdhyyyyyyyyyhdyyyyyyyyyydh:\033[1;33m---------------------------------------s/            -o/://:/+s             ");
    $display("\033[1;31m         os-:/oyhhhhyyyydhyyyyyyyyyds:\033[1;33m----------------------------------------:h:--.`      `y:------+os            ");
    $display("\033[1;33m         h+-----\033[1;31m:/+oosshdyyyyyyyyhds\033[1;33m-------------------------------------------+h//o+s+-.` :o-------s/y  ");
    $display("\033[1;33m         m:------------\033[1;31mdyyyyyyyyymo\033[1;33m--------------------------------------------oh----:://++oo------:s/d  ");
    $display("\033[1;33m        `N/-----------+\033[1;31mmyyyyyyyydo\033[1;33m---------------------------------------------sy---------:/s------+o/d  ");
    $display("\033[1;33m        .m-----------:d\033[1;31mhhyyyyyyd+\033[1;33m----------------------------------------------y+-----------+:-----oo/h  ");
    $display("\033[1;33m        +s-----------+N\033[1;31mhmyyyyhd/\033[1;33m----------------------------------------------:h:-----------::-----+o/m  ");
    $display("\033[1;33m        h/----------:d/\033[1;31mmmhyyhh:\033[1;33m-----------------------------------------------oo-------------------+o/h  ");
    $display("\033[1;33m       `y-----------so /\033[1;31mNhydh:\033[1;33m-----------------------------------------------/h:-------------------:soo  ");
    $display("\033[1;33m    `.:+o:---------+h   \033[1;31mmddhhh/:\033[1;33m---------------:/osssssoo+/::---------------+d+//++///::+++//::::::/y+`  ");
    $display("\033[1;33m   -s+/::/--------+d.   \033[1;31mohso+/+y/:\033[1;33m-----------:yo+/:-----:/oooo/:----------:+s//::-.....--:://////+/:`    ");
    $display("\033[1;33m   s/------------/y`           `/oo:--------:y/-------------:/oo+:------:/s:                                                 ");
    $display("\033[1;33m   o+:--------::++`              `:so/:-----s+-----------------:oy+:--:+s/``````                                             ");
    $display("\033[1;33m    :+o++///+oo/.                   .+o+::--os-------------------:oy+oo:`/o+++++o-                                           ");
    $display("\033[1;33m       .---.`                          -+oo/:yo:-------------------:oy-:h/:---:+oyo                                          ");
    $display("\033[1;33m                                          `:+omy/---------------------+h:----:y+//so                                         ");
    $display("\033[1;33m                                              `-ys:-------------------+s-----+s///om                                         ");
    $display("\033[1;33m                                                 -os+::---------------/y-----ho///om                                         ");
    $display("\033[1;33m                                                    -+oo//:-----------:h-----h+///+d                                         ");
    $display("\033[1;33m                                                       `-oyy+:---------s:----s/////y                                         ");
    $display("\033[1;33m                                                           `-/o+::-----:+----oo///+s                                         ");
    $display("\033[1;33m                                                               ./+o+::-------:y///s:                                         ");
    $display("\033[1;33m                                                                   ./+oo/-----oo/+h                                          ");
    $display("\033[1;33m                                                                       `://++++syo`                                          ");
    $display("\033[1;0m"); 
    repeat(5) @(negedge clk);
    $finish;
end endtask

endmodule
