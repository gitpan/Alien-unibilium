package Alien::make::Module::Build;

use strict;
use warnings;

use base qw( Module::Build );

use File::Basename qw( dirname );
use File::Spec;
use File::Path 2.07 qw( make_path );

use constant SRCDIR => "src";

BEGIN {
   # GNU make is called 'gmake' on most non-Linux platforms, gnumake on Dariwn.
   # Rather than hardcode it we'll try to identify a suitable command by inspection
   foreach my $make (qw( make gmake gnumake )) {
      no warnings 'exec';
      my $output = `$make --version`;
      next if $?;
      next unless $output =~ m/^GNU Make /;

      constant->import( MAKE => $make );
      last;
   }
   die "OS unsupported - unable to find GNU make\n" unless defined &MAKE;

   # GNU libtool is called 'glibtool' on Darwin
   foreach my $libtool (qw( libtool glibtool )) {
      no warnings 'exec';
      my $output = `$libtool --version`;
      next if $?;
      next unless $output =~ m/^.*\(GNU libtool\)/;

      constant->import( LIBTOOL => $libtool );
      last;
   }
   die "OS unsupported - unable to find GNU libtool\n" unless defined &LIBTOOL;

}

use constant MAKEARGS => ( ( LIBTOOL eq "libtool" ) ? ( "LIBTOOL=".LIBTOOL ) : () );

__PACKAGE__->add_property( 'tarball' );
__PACKAGE__->add_property( 'pkgconfig_module' );

sub _srcdir
{
   my $self = shift;
   return File::Spec->catdir( $self->base_dir, SRCDIR );
}

sub _stampfile
{
   my $self = shift;
   my ( $name ) = @_;

   return File::Spec->catfile( $self->base_dir, ".$name-stamp" );
}

sub in_srcdir
{
   my $self = shift;

   chdir( $self->_srcdir ) or
      die "Unable to chdir to srcdir - $!";

   shift->();
}

sub make_in_srcdir
{
   my $self = shift;
   my @args = @_;

   $self->in_srcdir( sub {
      system( MAKE, MAKEARGS, @args ) == 0 or
         die "Unable to make - $!";
   } );
}

sub ACTION_src
{
   my $self = shift;

   -d $self->_srcdir and return;

   my $tarball = $self->tarball;

   system( "tar", "xzf", $tarball ) == 0 or
      die "Unable to untar $tarball - $!";

   ( my $untardir = $tarball ) =~ s{\.tar\.[a-z]+$}{};

   -d $untardir or
      die "Expected to find a directory called $untardir\n";

   rename( $untardir, $self->_srcdir ) or
      die "Unable to rename src dir - $!";
}

sub ACTION_code
{
   my $self = shift;

   my $blib = File::Spec->catdir( $self->base_dir, "blib" );

   my $libdir = File::Spec->catdir( $blib, "arch" );
   my $incdir = File::Spec->catdir( $libdir, "include" );
   my $mandir = File::Spec->catdir( $blib, "libdoc" );

   my $pkgconfig_module = $self->pkgconfig_module;

   my $buildstamp = $self->_stampfile( "build" );

   unless( -f $buildstamp ) {
      $self->depends_on( 'src' );

      $self->make_in_srcdir( () );

      $self->make_in_srcdir( "install",
         "LIBDIR=$libdir",
         "INCDIR=$incdir",
         "MAN3DIR=$mandir",
         "MAN7DIR=$mandir",
      );

      open( my $stamp, ">", $buildstamp ) or die "Unable to touch .build-stamp file - $!";

      # Now hack the .pc file to put ${libdir}-relative paths in it
      my $pcfile = "$libdir/pkgconfig/$pkgconfig_module.pc";
      if( -f $pcfile ) {
         open my $in, "<", $pcfile or die "Cannot open $pcfile for reading - $!";
         open my $out, ">", "$pcfile.new" or die "Cannot open $pcfile.new for writing - $!";

         while( <$in> ) {
            s{\Q$libdir\E}{\${libdir}}g;
            print { $out } $_;
         }

         # Cygwin/Windows doesn't like it when you rename open files
         close $in;
         close $out;

         rename "$pcfile.new", $pcfile or die "Cannot rename $pcfile.new to $pcfile - $!";
      }
   }

   my @module_file = split m/::/, $self->module_name . ".pm";
   my $srcfile = File::Spec->catfile( $self->base_dir, "lib", @module_file );
   my $dstfile = File::Spec->catfile( $blib, "lib", @module_file );

   unless( $self->up_to_date( $srcfile, $dstfile ) ) {

      my %replace = (
         PKGCONFIG_MODULE => $pkgconfig_module,
      );

      # Turn ' into \' in replacements
      s/'/\\'/g for values %replace;

      $self->cp_file_with_replacement(
         srcfile => $srcfile,
         dstfile => $dstfile,
         replace => \%replace,
      );
   }
}

sub cp_file_with_replacement
{
   my $self = shift;
   my %args = @_;

   my $srcfile = $args{srcfile};
   my $dstfile = $args{dstfile};
   my $replace = $args{replace};

   make_path( dirname( $dstfile ), 0, 0777 );

   open( my $inh,  "<", $srcfile ) or die "Cannot read $srcfile - $!";
   open( my $outh, ">", $dstfile ) or die "Cannot write $dstfile - $!";

   while( my $line = <$inh> ) {
      $line =~ s/\@$_\@/$replace->{$_}/g for keys %$replace;
      print $outh $line;
   }
}

sub ACTION_test
{
   my $self = shift;

   $self->depends_on( "code" );

   $self->make_in_srcdir( "test" );
}

sub ACTION_clean
{
   my $self = shift;

   if( -d $self->_srcdir ) {
      $self->make_in_srcdir( "clean" );
   }

   unlink( $self->_stampfile( "build" ) );

   $self->SUPER::ACTION_clean;
}

sub ACTION_realclean
{
   my $self = shift;

   if( -d $self->_srcdir ) {
      system( "rm", "-rf", $self->_srcdir ); # best effort; ignore failure
   }

   $self->SUPER::ACTION_realclean;
}

0x55AA;
