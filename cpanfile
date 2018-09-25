# Should also be available as Debian packages
requires 'CGI';
requires 'Tie::IxHash';
requires 'LWP::Authen::Digest'; # libwww-perl
requires 'LWP::Simple'; # libwww-perl
requires 'LWP::UserAgent'; # libwww-perl
requires 'Image::Magick'; # libimage-magick-perl
requires 'XML::Encoding'; # libxml-encoding-perl
requires 'Text::Unaccent'; # libtext-unaccent-perl
requires 'MIME::Lite'; # libmime-lite-perl
requires 'Cache::Memcached::Fast'; #libcache-memcached-fast-perl
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
requires 'WWW::CSRF'; # libwww-csrf-perl
requires 'Apache2::Request'; # libapache2-request-perl
requires 'Digest::MD5'; # libdigest-md5-perl

# Probably not available as Debian packages
requires 'MongoDB', '>= 1.4.5'; # libmongodb-perl has an older version
requires 'URI::Escape::XS';
requires 'Encode::Punycode';
requires 'GraphViz2';
requires 'Algorithm::CheckDigits';
requires 'Geo::IP';
requires 'Image::OCR::Tesseract';
requires 'DateTime', '>= 1.50';
requires 'DateTime::Format::Mail';
requires 'DateTime::Locale', '>= 1.22';
requires 'Math::Random::Secure';
requires 'Crypt::ScryptKDF';
requires 'Locale::Maketext::Lexicon::Getcontext', '>= 0.05';
requires 'Email::IsEmail', '>= 3.04.8';
requires 'CLDR::Number::Format::Percent';
requires 'CLDR::Number';
requires 'Modern::Perl', '>= 1.20150127';
requires 'Data::Dumper::AutoEncode';
requires 'XML::Rules';
requires 'Email::Stuffer';

# Logging
requires 'Log::Any', '>= 1.705';
requires 'Log::Log4perl', '>= 1.49';
requires 'Log::Any::Adapter::Log4perl', '>= 0.09';

on 'test' => sub {
  requires 'Test::More', '>= 1.302049, < 2.0';
  requires 'Test::Perl::Critic';
  requires 'Test::Number::Delta';
};
