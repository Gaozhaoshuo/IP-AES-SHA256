################################################################################
#This is an internally genertaed by SpyGlass for Message Tagging Support
################################################################################


use spyglass;
use SpyGlass;
use SpyGlass::Objects;
spyRebootMsgTagSupport();

spySetMsgTagCount(19,34);
spyCacheTagValuesFromBatch(["AV_COMPLEXITY01_SS_SCH"]);
spyCacheTagValuesFromBatch(["AV_COMPLEXITY01_SS_SCH2"]);
spyCacheTagValuesFromBatch(["AV_FSM_SS_SCH"]);
spyCacheTagValuesFromBatch(["AV_INITSTATE01_SS_SCH"]);
spyCacheTagValuesFromBatch(["AV_INITSTATE01_SS_SCH01"]);
spyParseTextMessageTagFile("./sha256/sha256/adv_lint/adv_lint_struct/spyglass_spysch/sg_msgtag.txt");

if(!defined $::spyInIspy || !$::spyInIspy)
{
    spyDefineReportGroupingOrder("ALL",
(
"BUILTIN"   => [SGTAGTRUE, SGTAGFALSE]
,"TEMPLATE" => "A"
)
);
}
spyMessageTagTestBenchmark(62,"./sha256/sha256/adv_lint/adv_lint_struct/spyglass.vdb");

1;
