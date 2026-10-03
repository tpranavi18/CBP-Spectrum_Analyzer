verdiSetActWin -dock widgetDock_<Message>
simSetSimulator "-vcssv" -exec \
           "/home/student/Documents/23-088_hon/proj_dir_p/proj-dir/run/simv" \
           -args
debImport "-dbdir" \
          "/home/student/Documents/23-088_hon/proj_dir_p/proj-dir/run/simv.daidir"
debLoadSimResult \
           /home/student/Documents/23-088_hon/proj_dir_p/proj-dir/run/dump.fsdb
wvCreateWindow
verdiSetActWin -dock widgetDock_MTB_SOURCE_TAB_1
wvSelectGroup -win $_nWave2 {G1}
verdiSetActWin -win $_nWave2
wvGetSignalOpen -win $_nWave2
wvGetSignalSetScope -win $_nWave2 "/_vcs_msglog"
wvGetSignalSetScope -win $_nWave2 "/uart_standalone_tb"
wvGetSignalSetScope -win $_nWave2 "/uart_standalone_tb/dut"
wvGetSignalSetScope -win $_nWave2 \
           "/uart_standalone_tb/dut/axi_internal_fifo_rx_inst"
wvGetSignalSetScope -win $_nWave2 \
           "/uart_standalone_tb/dut/axi_internal_fifo_tx_inst"
wvGetSignalSetScope -win $_nWave2 "/uart_standalone_tb/dut/uart_controller_inst"
wvGetSignalSetScope -win $_nWave2 \
           "/uart_standalone_tb/dut/axi_internal_fifo_tx_inst"
wvGetSignalSetScope -win $_nWave2 \
           "/uart_standalone_tb/dut/axi_internal_fifo_rx_inst"
wvGetSignalSetScope -win $_nWave2 \
           "/uart_standalone_tb/dut/axi_internal_fifo_tx_inst"
wvGetSignalSetScope -win $_nWave2 \
           "/uart_standalone_tb/dut/axi_internal_fifo_rx_inst"
wvGetSignalSetScope -win $_nWave2 "/uart_standalone_tb"
wvGetSignalSetScope -win $_nWave2 "/uart_standalone_tb/dut"
wvGetSignalSetScope -win $_nWave2 \
           "/uart_standalone_tb/dut/axi_internal_fifo_rx_inst"
wvGetSignalSetScope -win $_nWave2 \
           "/uart_standalone_tb/dut/axi_internal_fifo_tx_inst"
wvGetSignalSetScope -win $_nWave2 "/uart_standalone_tb/dut/uart_controller_inst"
wvGetSignalSetScope -win $_nWave2 "/uart_standalone_tb/dut"
wvGetSignalSetScope -win $_nWave2 "/uart_standalone_tb"
wvSetPosition -win $_nWave2 {("G1" 16)}
wvSetPosition -win $_nWave2 {("G1" 16)}
wvAddSignal -win $_nWave2 -clear
wvAddSignal -win $_nWave2 -group {"G1" \
{/uart_standalone_tb/axi_araddr_i\[4:0\]} \
{/uart_standalone_tb/axi_aresetn_i} \
{/uart_standalone_tb/axi_arready_o} \
{/uart_standalone_tb/axi_arvalid_i} \
{/uart_standalone_tb/axi_awaddr_i\[4:0\]} \
{/uart_standalone_tb/axi_awready_o} \
{/uart_standalone_tb/axi_awvalid_i} \
{/uart_standalone_tb/axi_rdata_o\[31:0\]} \
{/uart_standalone_tb/axi_rvalid_o} \
{/uart_standalone_tb/axi_wdata_i\[31:0\]} \
{/uart_standalone_tb/axi_wready_o} \
{/uart_standalone_tb/axi_wvalid_i} \
{/uart_standalone_tb/fixed_clk_i} \
{/uart_standalone_tb/read_interrupt_o} \
{/uart_standalone_tb/uart_rx_i} \
{/uart_standalone_tb/uart_tx_o} \
}
wvAddSignal -win $_nWave2 -group {"G2" \
}
wvSelectSignal -win $_nWave2 {( "G1" 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 )} \
           
wvSetPosition -win $_nWave2 {("G1" 16)}
wvSetPosition -win $_nWave2 {("G1" 16)}
wvSetPosition -win $_nWave2 {("G1" 16)}
wvAddSignal -win $_nWave2 -clear
wvAddSignal -win $_nWave2 -group {"G1" \
{/uart_standalone_tb/axi_araddr_i\[4:0\]} \
{/uart_standalone_tb/axi_aresetn_i} \
{/uart_standalone_tb/axi_arready_o} \
{/uart_standalone_tb/axi_arvalid_i} \
{/uart_standalone_tb/axi_awaddr_i\[4:0\]} \
{/uart_standalone_tb/axi_awready_o} \
{/uart_standalone_tb/axi_awvalid_i} \
{/uart_standalone_tb/axi_rdata_o\[31:0\]} \
{/uart_standalone_tb/axi_rvalid_o} \
{/uart_standalone_tb/axi_wdata_i\[31:0\]} \
{/uart_standalone_tb/axi_wready_o} \
{/uart_standalone_tb/axi_wvalid_i} \
{/uart_standalone_tb/fixed_clk_i} \
{/uart_standalone_tb/read_interrupt_o} \
{/uart_standalone_tb/uart_rx_i} \
{/uart_standalone_tb/uart_tx_o} \
}
wvAddSignal -win $_nWave2 -group {"G2" \
}
wvSelectSignal -win $_nWave2 {( "G1" 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 )} \
           
wvSetPosition -win $_nWave2 {("G1" 16)}
wvSetPosition -win $_nWave2 {("G1" 16)}
wvSetPosition -win $_nWave2 {("G1" 16)}
wvAddSignal -win $_nWave2 -clear
wvAddSignal -win $_nWave2 -group {"G1" \
{/uart_standalone_tb/axi_araddr_i\[4:0\]} \
{/uart_standalone_tb/axi_aresetn_i} \
{/uart_standalone_tb/axi_arready_o} \
{/uart_standalone_tb/axi_arvalid_i} \
{/uart_standalone_tb/axi_awaddr_i\[4:0\]} \
{/uart_standalone_tb/axi_awready_o} \
{/uart_standalone_tb/axi_awvalid_i} \
{/uart_standalone_tb/axi_rdata_o\[31:0\]} \
{/uart_standalone_tb/axi_rvalid_o} \
{/uart_standalone_tb/axi_wdata_i\[31:0\]} \
{/uart_standalone_tb/axi_wready_o} \
{/uart_standalone_tb/axi_wvalid_i} \
{/uart_standalone_tb/fixed_clk_i} \
{/uart_standalone_tb/read_interrupt_o} \
{/uart_standalone_tb/uart_rx_i} \
{/uart_standalone_tb/uart_tx_o} \
}
wvAddSignal -win $_nWave2 -group {"G2" \
}
wvSelectSignal -win $_nWave2 {( "G1" 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 )} \
           
wvSetPosition -win $_nWave2 {("G1" 16)}
wvGetSignalClose -win $_nWave2
verdiDockWidgetMaximize -dock windowDock_nWave_2
wvZoomAll -win $_nWave2
wvZoomAll -win $_nWave2
wvSelectSignal -win $_nWave2 {( "G1" 13 )} 
wvSetPosition -win $_nWave2 {("G1" 13)}
wvSetPosition -win $_nWave2 {("G1" 12)}
wvMoveSelected -win $_nWave2
wvSetPosition -win $_nWave2 {("G1" 12)}
wvSetPosition -win $_nWave2 {("G1" 13)}
wvSetPosition -win $_nWave2 {("G1" 12)}
wvSetPosition -win $_nWave2 {("G1" 11)}
wvSetPosition -win $_nWave2 {("G1" 10)}
wvSetPosition -win $_nWave2 {("G1" 9)}
wvSetPosition -win $_nWave2 {("G1" 8)}
wvSetPosition -win $_nWave2 {("G1" 7)}
wvSetPosition -win $_nWave2 {("G1" 6)}
wvSetPosition -win $_nWave2 {("G1" 5)}
wvSetPosition -win $_nWave2 {("G1" 4)}
wvSetPosition -win $_nWave2 {("G1" 3)}
wvSetPosition -win $_nWave2 {("G1" 2)}
wvSetPosition -win $_nWave2 {("G1" 1)}
wvMoveSelected -win $_nWave2
wvSetPosition -win $_nWave2 {("G1" 1)}
wvSetPosition -win $_nWave2 {("G1" 2)}
wvSetPosition -win $_nWave2 {("G1" 1)}
wvSetPosition -win $_nWave2 {("G1" 0)}
wvMoveSelected -win $_nWave2
wvSetPosition -win $_nWave2 {("G1" 0)}
wvSetPosition -win $_nWave2 {("G1" 1)}
wvSelectGroup -win $_nWave2 {G2}
wvSelectSignal -win $_nWave2 {( "G1" 3 )} 
wvSelectSignal -win $_nWave2 {( "G1" 3 )} 
wvSelectSignal -win $_nWave2 {( "G1" 3 )} 
wvSelectSignal -win $_nWave2 {( "G1" 3 )} 
wvSelectGroup -win $_nWave2 {G2}
wvSelectSignal -win $_nWave2 {( "G1" 3 )} 
wvSetPosition -win $_nWave2 {("G1" 3)}
wvSetPosition -win $_nWave2 {("G1" 2)}
wvSetPosition -win $_nWave2 {("G1" 1)}
wvSetPosition -win $_nWave2 {("G1" 0)}
wvMoveSelected -win $_nWave2
wvSetPosition -win $_nWave2 {("G1" 0)}
wvSetPosition -win $_nWave2 {("G1" 1)}
wvSetPosition -win $_nWave2 {("G1" 2)}
wvMoveSelected -win $_nWave2
wvSetPosition -win $_nWave2 {("G1" 2)}
wvSelectGroup -win $_nWave2 {G2}
wvSelectSignal -win $_nWave2 {( "G1" 6 )} 
wvSetPosition -win $_nWave2 {("G1" 6)}
wvSetPosition -win $_nWave2 {("G1" 5)}
wvSetPosition -win $_nWave2 {("G1" 4)}
wvSetPosition -win $_nWave2 {("G1" 3)}
wvMoveSelected -win $_nWave2
wvSetPosition -win $_nWave2 {("G1" 3)}
wvSetPosition -win $_nWave2 {("G1" 4)}
wvSetPosition -win $_nWave2 {("G1" 3)}
wvMoveSelected -win $_nWave2
wvSetPosition -win $_nWave2 {("G1" 3)}
wvSetPosition -win $_nWave2 {("G1" 4)}
wvSetPosition -win $_nWave2 {("G1" 3)}
wvSetPosition -win $_nWave2 {("G1" 2)}
wvMoveSelected -win $_nWave2
wvSetPosition -win $_nWave2 {("G1" 2)}
wvSetPosition -win $_nWave2 {("G1" 3)}
wvSelectSignal -win $_nWave2 {( "G1" 8 )} 
wvSetPosition -win $_nWave2 {("G1" 8)}
wvSetPosition -win $_nWave2 {("G1" 7)}
wvSetPosition -win $_nWave2 {("G1" 6)}
wvSetPosition -win $_nWave2 {("G1" 5)}
wvSetPosition -win $_nWave2 {("G1" 4)}
wvSetPosition -win $_nWave2 {("G1" 3)}
wvMoveSelected -win $_nWave2
wvSetPosition -win $_nWave2 {("G1" 3)}
wvSetPosition -win $_nWave2 {("G1" 4)}
wvSelectSignal -win $_nWave2 {( "G1" 8 )} 
wvSetPosition -win $_nWave2 {("G1" 8)}
wvSetPosition -win $_nWave2 {("G1" 7)}
wvSetPosition -win $_nWave2 {("G1" 6)}
wvSetPosition -win $_nWave2 {("G1" 5)}
wvSetPosition -win $_nWave2 {("G1" 4)}
wvSetPosition -win $_nWave2 {("G1" 5)}
wvMoveSelected -win $_nWave2
wvSetPosition -win $_nWave2 {("G1" 5)}
wvSetPosition -win $_nWave2 {("G1" 6)}
wvSetPosition -win $_nWave2 {("G1" 5)}
wvSetPosition -win $_nWave2 {("G1" 4)}
wvMoveSelected -win $_nWave2
wvSetPosition -win $_nWave2 {("G1" 4)}
wvSetPosition -win $_nWave2 {("G1" 5)}
wvSelectGroup -win $_nWave2 {G2}
wvSelectSignal -win $_nWave2 {( "G1" 11 )} 
wvSetPosition -win $_nWave2 {("G1" 11)}
wvSetPosition -win $_nWave2 {("G1" 10)}
wvSetPosition -win $_nWave2 {("G1" 9)}
wvSetPosition -win $_nWave2 {("G1" 8)}
wvSetPosition -win $_nWave2 {("G1" 7)}
wvSetPosition -win $_nWave2 {("G1" 6)}
wvSetPosition -win $_nWave2 {("G1" 5)}
wvMoveSelected -win $_nWave2
wvSetPosition -win $_nWave2 {("G1" 5)}
wvSetPosition -win $_nWave2 {("G1" 6)}
wvSelectSignal -win $_nWave2 {( "G1" 13 )} 
wvSetPosition -win $_nWave2 {("G1" 13)}
wvSetPosition -win $_nWave2 {("G1" 12)}
wvSetPosition -win $_nWave2 {("G1" 11)}
wvSetPosition -win $_nWave2 {("G1" 10)}
wvSetPosition -win $_nWave2 {("G1" 9)}
wvSetPosition -win $_nWave2 {("G1" 8)}
wvSetPosition -win $_nWave2 {("G1" 7)}
wvSetPosition -win $_nWave2 {("G1" 6)}
wvSetPosition -win $_nWave2 {("G1" 7)}
wvSetPosition -win $_nWave2 {("G1" 6)}
wvMoveSelected -win $_nWave2
wvSetPosition -win $_nWave2 {("G1" 6)}
wvSetPosition -win $_nWave2 {("G1" 7)}
wvSelectSignal -win $_nWave2 {( "G1" 13 )} 
wvSetPosition -win $_nWave2 {("G1" 13)}
wvSetPosition -win $_nWave2 {("G1" 12)}
wvSetPosition -win $_nWave2 {("G1" 11)}
wvSetPosition -win $_nWave2 {("G1" 10)}
wvSetPosition -win $_nWave2 {("G1" 9)}
wvSetPosition -win $_nWave2 {("G1" 8)}
wvSetPosition -win $_nWave2 {("G1" 7)}
wvMoveSelected -win $_nWave2
wvSetPosition -win $_nWave2 {("G1" 7)}
wvSetPosition -win $_nWave2 {("G1" 8)}
wvSelectGroup -win $_nWave2 {G2}
wvSelectSignal -win $_nWave2 {( "G1" 11 )} 
wvSetPosition -win $_nWave2 {("G1" 11)}
wvSetPosition -win $_nWave2 {("G1" 10)}
wvSetPosition -win $_nWave2 {("G1" 9)}
wvMoveSelected -win $_nWave2
wvSetPosition -win $_nWave2 {("G1" 9)}
wvSetPosition -win $_nWave2 {("G1" 10)}
wvSelectGroup -win $_nWave2 {G2}
wvSelectGroup -win $_nWave2 {G2}
wvSelectGroup -win $_nWave2 {G2}
wvZoomAll -win $_nWave2
wvSelectSignal -win $_nWave2 {( "G1" 14 )} 
wvSetPosition -win $_nWave2 {("G1" 14)}
wvSetPosition -win $_nWave2 {("G1" 15)}
wvSetPosition -win $_nWave2 {("G1" 16)}
wvMoveSelected -win $_nWave2
wvSetPosition -win $_nWave2 {("G1" 16)}
wvSelectGroup -win $_nWave2 {G2}
wvZoomAll -win $_nWave2
debExit
