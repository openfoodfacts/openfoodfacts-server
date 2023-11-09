# Should also be available as Debian packages
# If a minimum version number is specified, "cpanm --skip-satisfied" will install a newer version than apt if one is available in cpan.

requires 'CGI', '>= 4.53, < 5.0'; # libcgi-pm-perl
requires 'Tie::IxHash'; # libtie-ixhash-perl
requires 'LWP::Authen::Digest'; # libwww-perl
requires 'LWP::Simple'; # libwww-perl
requires 'LWP::UserAgent'; # libwww-perl
requires 'Image::Magick'; # libimage-magick-perl
requires 'XML::Encoding'; # libxml-encoding-perl
requires 'MIME::Lite'; # libmime-lite-perl
requires 'MIME::Base32';
requires 'Cache::Memcached::Fast'; #libcache-memcached-fast-perl
requires 'JSON'; # libjson-perl
requires 'JSON::PP'; # libjson-pp-perl
requires 'Clone'; # libclone-perl
requires 'Crypt::PasswdMD5'; # libcrypt-passwdmd5-perl
requires 'Encode::Detect'; # libencode-detect-perl
requires 'Graphics::Color::RGB'; # libgraphics-color-perl
requires 'Graphics::Color::HSL'; # libgraphics-color-perl
requires 'Barcode::ZBar'; # libbarcode-zbar-perl
requires 'XML::FeedPP'; # libxml-feedpp-perl
requires 'URI::Find'; # liburi-find-perl
requires 'XML::Simple'; # libxml-simple-perl
requires 'experimental'; # libexperimental-perl
requires 'Apache2::Request'; # libapache2-request-perl
requires 'Digest::MD5'; # libdigest-md5-perl
requires 'Time::Local'; # libtime-local-perl
requires 'Template', '>= 3.009'; # libtemplate-perl
requires 'URI::Escape::XS'; # liburi-escape-xs-perl
requires 'Math::Random::Secure'; # libmath-random-secure-perl. deps: libtest-sharedfork-perl, libtest-warn-perl, libmath-random-isaac-perl, libcrypt-random-source-perl
requires 'Email::Stuffer', '>= 0.018'; # libemail-stuffer-perl
requires 'File::Copy::Recursive', '>= 0.45'; # libfile-copy-recursive-perl
requires 'List::MoreUtils', '>= 0.430'; # liblist-moreutils-perl
requires 'Excel::Writer::XLSX', '>= 1.09'; # libexcel-writer-xlsx-perl
requires 'Pod::Simple::HTMLBatch'; # libpod-simple-perl
requires 'GeoIP2', '>= 2.006002, < 3.0'; # libgeoip2-perl, deps: libdata-validate-ip-perl libio-compress-perl libjson-maybexs-perl liblist-someutils-perl, libdata-dumper-concise-perl, libdata-printer-perl
requires 'Email::Valid', '>= 1.202, < 2.0'; # libemail-valid-perl
requires 'Path::Tiny', '>= 0.118'; # libpath-tiny-perl

# Probably not available as Debian/Ubuntu packages
requires 'MongoDB', '>= 2.2.2, < 2.3'; # libmongodb-perl has 1.8.1/2.0.3 vs 2.2.2. deps: libauthen-sasl-saslprep-perl, libbson-perl, libauthen-scram-perl, libclass-xsaccessor-perl, libdigest-hmac-perl, libsafe-isa-perl, libconfig-autoconf-perl, libpath-tiny-perl
# we fix this because MongoDB depends on it, and 0.023 does not install correctly
requires 'Type::Tiny::XS', '==0.022';
requires 'Encode::Punycode'; # deps: libnet-idn-encode-perl, libtest-nowarnings-perl
requires 'GraphViz2'; # deps: libfile-which-perl, libdata-section-simple-perl, libwant-perl, libipc-run3-perl, liblog-handler-perl, libtest-deep-perl
requires 'Algorithm::CheckDigits'; # libalgorithm-checkdigits-perl has 0.50 vs 1.3.3. deps: libprobe-perl-perl
requires 'Image::OCR::Tesseract'; # deps: libfile-find-rule-perl
requires 'DateTime', '>= 1.54, < 2.0'; # libdatetime-perl has 1.46. deps: libclass-singleton-perl
requires 'DateTime::Locale', '>= 1.32, < 2.0'; # libdatetime-locale-perl has 1.17. deps: libfile-sharedir-install-perl
requires 'DateTime::Format::ISO8601'; # libdatetime-format-iso8601-perl
requires 'Crypt::ScryptKDF';
requires 'Locale::Maketext::Lexicon::Getcontext', '>= 0.05'; # deps: liblocale-maketext-lexicon-perl
requires 'CLDR::Number::Format::Decimal';
requires 'CLDR::Number::Format::Percent';
requires 'CLDR::Number'; # deps: libmath-round-perl, libtest-differences-perl, libsoftware-license-perl
requires 'Modern::Perl', '>= 1.20200211'; # libmodern-perl-perl has 1.20170117/1.20180901
requires 'Data::Dumper::AutoEncode'; # deps: libmodule-build-pluggable-perl, libclass-accessor-lite-perl
requires 'XML::Rules';
requires 'Text::CSV', '>= 2.01, < 3.0'; # libtext-csv-perl has 1.95/1.99 vs 2.00.
requires 'Text::CSV_XS';
requires 'Text::Fuzzy';
requires 'Spreadsheet::CSV'; # deps: libspreadsheet-parseexcel-perl
requires 'File::chmod::Recursive'; # deps: libfile-chmod-perl
requires 'Devel::Size'; # deps: libdevel-size-perl
requires 'JSON::Create';
requires 'JSON::Parse';
requires 'Data::DeepAccess';
requires 'XML::XML2JSON';
requires 'Redis';
requires 'Digest::SHA1';
requires 'Data::Difference';

# Mojolicious/Minion
requires 'Mojolicious::Lite';
requires 'Minion'; # libminion-perl has 9.09 vs 10.13.
requires 'Mojo::Pg'; # libmojo-pg-perl has 4.13 vs 4.19. deps: libsql-abstract-perl

# Logging
requires 'Log::Any', '>= 1.710, < 2.0'; # liblog-any-perl has 1.707
requires 'Log::Log4perl', '>= 1.54, < 2.0'; # liblog-log4perl-perl
requires 'Log::Any::Adapter::Log4perl', '>= 0.09'; # liblog-any-adapter-log4perl-perl

# Retry
requires 'Action::CircuitBreaker';
requires 'Action::Retry'; # deps: libmath-fibonacci-perl

# AnyEvent
requires 'AnyEvent';
requires 'AnyEvent::Inotify::Simple';

# GS1 Encoder
requires 'GS1::SyntaxEngine::FFI';

on 'test' => sub {
  requires 'Test::More', '>= 1.302186, < 2.0';
  requires 'Test::MockModule';
  requires 'Mock::Quick';
  requires 'Test::Number::Delta'; # libtest-number-delta-perl
  requires 'Test::Files';
  requires 'File::Spec';
  requires 'Log::Any::Adapter::TAP'; # liblog-any-adapter-tap-perl
  requires 'IO::Capture::Stdout::Extended';
  requires 'IO::Capture::Stderr::Extended';
  requires 'HTTP::CookieJar::LWP';
  requires 'File::Tail';
  requires 'Test2::Plugin::UTF8';
  requires 'Devel::Cover';
  requires 'Devel::Cover::Report::Codecov';
  requires 'Devel::Cover::Report::Codecovbash';
  requires 'Test::Fake::HTTPD';
  requires 'URL::Encode';
};

on 'develop' => sub {
  requires 'Test::Perl::Critic', '>=1.04', '<2.0'; # perl-critic refuse to install without this explicit deps
  requires 'Perl::Critic', '>= 1.140, < 2.0'; # libperl-critic-perl has 1.132 vs 1.138, and all the depended on packages are old too.
  requires 'Apache::DB', '>= 0.18, < 1.00'; # old non-working version also available as the Debian package libapache-db-perl 0.14
  requires 'Perl::Tidy';
  requires 'Perl::Critic';
  requires 'Devel::Cover';
  requires 'Devel::Cover::Report::Codecov';
  requires 'Devel::Cover::Report::Codecovbash';
};

feature "off_server_dev_tools", "Optional development tools" => sub {
  # Modules needed to ease development but not need to run CI tasks or automated tests
  # on GitHub, or for production
  # For docker, use CPANMOPTS=--with-develop  --with-feature=off_server_dev_tools
  requires 'Devel::REPL';
  requires 'Term::ReadLine::Gnu', '>= 1.42, < 2.0'; # readline support for the Perl debugger. libterm-readline-gnu-perl is available.
  requires 'Perl::LanguageServer';
  requires 'Hash::SafeKeys';  # Perl::LanguageServer dependency
};

