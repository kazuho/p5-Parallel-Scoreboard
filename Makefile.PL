use inc::Module::Install;

name 'Parallel-Scoreboard';
all_from 'lib/Parallel/Scoreboard.pm';

license 'perl';
readme_from 'lib/Parallel/Scoreboard.pm';

test_requires 'File::Temp';
test_requires 'Test::More';
use_test_base;
auto_include;
WriteAll;
