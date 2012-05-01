use strict;
use warnings;

use lib 'inc';
use Alien::unibilium::Module::Build;

my $build = Alien::unibilium::Module::Build->new(
   module_name => 'Alien::unibilium',
   tarball => 'unibilium-v1.0.0.tar.gz',
   pkgconfig_module => "unibilium",

   configure_requires => {
      'ExtUtils::PkgConfig' => 0,
      'Module::Build' => 0,
   },
   requires => {
      'ExtUtils::PkgConfig' => 0,
      'File::Basename' => 0,
      'File::Path' => '2.07',
      'File::Spec' => 0,
   },
   license => 'perl',
   create_makefile_pl => 'small',
   create_license => 1,
   create_readme  => 1,
);

$build->create_build_script;
