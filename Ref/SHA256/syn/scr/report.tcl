#--------------------------#
# report compile results   #
#--------------------------#

set   check_design_name       [format "%s%s%s%s%s" $report_name _check_design _ $stage .rpt]
set   check_timing_name       [format "%s%s%s%s%s" $report_name _check_timing _ $stage .rpt]
set   report_design_name      [format "%s%s%s%s%s" $report_name _report_design _ $stage .rpt]
set   report_port_name        [format "%s%s%s%s%s" $report_name _report_port _ $stage .rpt]
set   check_clock_name        [format "%s%s%s%s%s" $report_name _clock_info _ $stage .rpt]
set   check_gated_clock_name  [format "%s%s%s%s%s" $report_name _gated_clock _ $stage .rpt]
set   check_fanout_name       [format "%s%s%s%s%s" $report_name _fanout _ $stage .rpt]
set   check_reference_name    [format "%s%s%s%s%s" $report_name _reference _ $stage .rpt]
set   check_resource_name     [format "%s%s%s%s%s" $report_name _resource _ $stage .rpt]
set   check_timing_require_name    [format "%s%s%s%s%s" $report_name _timing_require _ $stage .rpt]
set   check_timing_ignored_name    [format "%s%s%s%s%s" $report_name _timing_ignored _ $stage .rpt]
set   check_area_name         [format "%s%s%s%s%s" $report_name _area _ $stage .rpt]       
set   check_setup_name        [format "%s%s%s%s%s" $report_name _setuptiming _ $stage .rpt]
set   check_hold_name         [format "%s%s%s%s%s" $report_name _holdtiming _ $stage .rpt]
set   check_qor_name          [format "%s%s%s%s%s" $report_name _qor_info _ $stage .rpt]
set   check_violation_name    [format "%s%s%s%s%s" $report_name _violation _ $stage .rpt]
set   check_drc_name          [format "%s%s%s%s%s" $report_name _drc_info _ $stage .rpt]
set   check_case_analy_name   [format "%s%s%s%s%s" $report_name _case_analy _ $stage .rpt]
set   check_disable_timing_name    [format "%s%s%s%s%s" $report_name _timing_disable _ $stage .rpt]


puts  "#------------------------#"
puts  "# generate report now    #"
puts  "#------------------------#"

redirect    $check_design_name      {check_design}
redirect    $check_timing_name      {check_timing}
redirect    $report_design_name     {report_design     -nosplit}
redirect    $report_port_name       {report_port  -verbose  -nosplit}
redirect    $check_clock_name       {report_clocks  -nosplit}
redirect  -append $check_clock_name {report_clocks  -skew  -nosplit}
redirect    $check_gated_clock_name {report_clock_gating  -gating_elements  -gated  \
                                     -ungated  -hier  -verbose  -nosplit}
redirect    $check_fanout_name      {report_net_fanout  -threshold  25  -nosplit}
redirect    $check_reference_name   {report_reference  -hierarchy  -nosplit}
redirect    $check_resource_name    {report_resources  -hierarchy  -nosplit}
##redirect    $check_timing_require_name    {report_timing_requirements  -nosplit}
##redirect    $check_timing_ignored_name    {report_timing_requirements  -nosplit -ignored}
redirect    $check_area_name        {report_area  -hierarchy  -nosplit}
redirect    $check_setup_name       {report_timing -delay max  -max_paths 100 -nosplit}
redirect    $check_hold_name        {report_timing -delay min  -max_paths 100 -nosplit}
redirect    $check_qor_name         {report_qor  -nosplit}
redirect    $check_violation_name   {report_constrain  -all_violators  -verbose -nosplit}
redirect    $check_drc_name         {report_constrain  -max_capacitance  -max_transition \
                                     -max_fanout  -verbose -nosplit}
redirect    $check_case_analy_name  {report_case_analysis}                                
redirect    $check_disable_timing_name  {report_disable_timing}                                
