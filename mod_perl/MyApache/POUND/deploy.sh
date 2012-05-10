#!/bin/sh

scp `ls *.pm|grep -v POUNDConfig.pm` pgunn@blog.dachte.org:~/mod_perl/MyApache/POUND/
echo "Remember: POUNDConfig.pm is not synced"
echo "any changes to it must be merged manually"

