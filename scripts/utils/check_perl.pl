#!/usr/bin/perl -w

# check perl file compiles

use ProductOpener::PerlStandards;

use Module::Load;
use File::Temp;

my $tmp_dir = File::Temp->newdir();
my $tmp_dirname = $tmp_dir->dirname();

my @files = @ARGV;

my %errors = ();

# simply check if files compile
foreach my $file (@files) {
    my $module;
    my $script;
    my $err;
    my @std_err;
    if ($file =~ m/\.pm$/) {
        $module = $file;
        $module =~ s|/|::|g;
        # remove lib::
        $module =~ s/^lib:://;
        # remove .pm from end if present
        $module =~ s/\.pm$//;
    }
    if ($module) {
        print "Checking $module...\n";
        #eval "use $module";
        {
            local *STDERR;
            open(STDERR, '>', "$tmp_dirname/err.txt");
            STDERR->autoflush(1);  # needed to be able to read output immediately
            eval("use $module");
            $err = $@;
            close(STDERR);
            open(my $ERR, "<", "$tmp_dirname/err.txt");
            @std_err = <$ERR>;
            close($ERR);
        };
        $errors{$file} = {err => $err, std_err => join("", @std_err)} if $err;
    }
    else {
        $errors{$file} = {err => "Not a Perl module, use perl -c instead", std_err => ""};
    }
}

my $ko_count = scalar keys %errors;
my $ok_count = (scalar @files) - $ko_count;
print("$ok_count files ok.\n");
if (keys %errors) {
    foreach my $file (keys %errors) {
        print("----------------------------------------\n");
        print("$file failed to compile:\n");
        print("----------------------------------------\n");
        print("$errors{$file}{err}\n");
        print("----------------------------------------\n");
        print("$errors{$file}{std_err}\n");
        print("----------------------------------------\n");
    }
}

die("Errors in $ko_count files… existing with an error !") if $ko_count;
1;