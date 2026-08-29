verdiSetActWin -dock widgetDock_<Message>
simSetSimulator "-vcssv" -exec \
           "/home/student/Documents/078_Honours/proj-dir/run/simv" -args
debImport "-dbdir" "/home/student/Documents/078_Honours/proj-dir/run/simv.daidir"
debLoadSimResult /home/student/Documents/078_Honours/proj-dir/run/dump.fsdb
wvCreateWindow
verdiSetActWin -dock widgetDock_MTB_SOURCE_TAB_1
wvSelectGroup -win $_nWave2 {G1}
verdiSetActWin -win $_nWave2
wvGetSignalOpen -win $_nWave2
wvGetSignalSetScope -win $_nWave2 "/_vcs_msglog"
wvGetSignalSetScope -win $_nWave2 \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst"
wvGetSignalSetScope -win $_nWave2 \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/arb_inst"
wvGetSignalSetScope -win $_nWave2 \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst"
verdiWindowResize -win $_Verdi_1 "199" "98" "1200" "617"
wvSetPosition -win $_nWave2 {("G1" 8)}
wvSetPosition -win $_nWave2 {("G1" 8)}
wvAddSignal -win $_nWave2 -clear
wvAddSignal -win $_nWave2 -group {"G1" \
{/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/m_axi_araddr\[447:0\]} \
{/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/m_axi_awaddr\[447:0\]} \
{/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/m_axi_rdata\[447:0\]} \
{/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/m_axi_wdata\[447:0\]} \
{/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_araddr\[95:0\]} \
{/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[95:0\]} \
{/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_rdata\[95:0\]} \
{/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_wdata\[95:0\]} \
}
wvAddSignal -win $_nWave2 -group {"G2" \
}
wvSelectSignal -win $_nWave2 {( "G1" 1 2 3 4 5 6 7 8 )} 
wvSetPosition -win $_nWave2 {("G1" 8)}
wvSetPosition -win $_nWave2 {("G1" 8)}
wvSetPosition -win $_nWave2 {("G1" 8)}
wvAddSignal -win $_nWave2 -clear
wvAddSignal -win $_nWave2 -group {"G1" \
{/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/m_axi_araddr\[447:0\]} \
{/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/m_axi_awaddr\[447:0\]} \
{/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/m_axi_rdata\[447:0\]} \
{/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/m_axi_wdata\[447:0\]} \
{/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_araddr\[95:0\]} \
{/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[95:0\]} \
{/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_rdata\[95:0\]} \
{/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_wdata\[95:0\]} \
}
wvAddSignal -win $_nWave2 -group {"G2" \
}
wvSelectSignal -win $_nWave2 {( "G1" 1 2 3 4 5 6 7 8 )} 
wvSetPosition -win $_nWave2 {("G1" 8)}
wvGetSignalClose -win $_nWave2
wvSetCursor -win $_nWave2 137641.225139 -snap {("G1" 0)}
wvZoomAll -win $_nWave2
verdiDockWidgetMaximize -dock windowDock_nWave_2
wvSelectSignal -win $_nWave2 {( "G1" 8 )} 
wvSelectSignal -win $_nWave2 {( "G1" 1 )} 
wvSelectSignal -win $_nWave2 {( "G1" 5 )} 
wvSelectSignal -win $_nWave2 {( "G1" 6 )} 
wvCreateBusOpen -win $_nWave2
wvSetPosition -win $_nWave2 {("G1" 8)}
wvSetPosition -win $_nWave2 {("G1" 8)}
wvSetPosition -win $_nWave2 {("G1" 9)}
wvSetPosition -win $_nWave2 {("G1" 8)}
wvSetPosition -win $_nWave2 {("G1" 8)}
wvCreateBus -win $_nWave2 "s0_axi_awaddr\[31:0\]" \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[31\]" \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[30\]" \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[29\]" \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[28\]" \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[27\]" \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[26\]" \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[25\]" \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[24\]" \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[23\]" \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[22\]" \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[21\]" \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[20\]" \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[19\]" \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[18\]" \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[17\]" \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[16\]" \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[15\]" \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[14\]" \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[13\]" \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[12\]" \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[11\]" \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[10\]" \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[9\]" \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[8\]" \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[7\]" \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[6\]" \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[5\]" \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[4\]" \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[3\]" \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[2\]" \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[1\]" \
           "/tb_axi_interconnect_wrap_3x14/dut/axi_interconnect_inst/s_axi_awaddr\[0\]"
wvSetPosition -win $_nWave2 {("G1" 9)}
wvSetPosition -win $_nWave2 {("G1" 9)}
wvSelectSignal -win $_nWave2 {( "G1" 9 )} 
wvCut -win $_nWave2
wvSetPosition -win $_nWave2 {("G2" 0)}
wvSetPosition -win $_nWave2 {("G1" 8)}
wvSetCursor -win $_nWave2 917863.959581 -snap {("G2" 0)}
wvZoomAll -win $_nWave2
wvZoomAll -win $_nWave2
