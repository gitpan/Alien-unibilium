#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2012 -- leonerd@leonerd.org.uk

package Alien::unibilium;

our $VERSION = '0.06';

# libdir is the first @INC path that contains a pkgconfig/ dir
my $libdir;
foreach my $inc ( @INC ) {
   $libdir = $inc and last if -d "$inc/pkgconfig";
}
defined $libdir or die "Cannot find my libdir containing pkgconfig";

my $module = '@PKGCONFIG_MODULE@';

=head1 NAME

C<Alien::unibilium> - L<Alien> wrapping for F<unibilium>

=head1 DESCRIPTION

This CPAN distribution installs a local copy of F<unibilium>, primarily for
use by the F<libtermkey> or the L<Term::Terminfo> distribution. It is not
intended to be used directly.

This module bundles F<unibilium> version v1.0.1.

=head1 METHODS

This module behaves like L<ExtUtils::PkgConfig>, responding to the same
methods, except that the module name is implied. Thus, the configuration can
be obtained by calling

 $cflags = Alien::unibilium->cflags
 $libs = Alien::unibilium->libs

 $ok = Alien::unibilium->atleast_version( $version )

 etc...

=cut

# I AM EVIL
sub AUTOLOAD
{
   our $AUTOLOAD =~ s/^.*:://;
   return _get_pkgconfig( $AUTOLOAD, @_ );
}

sub _get_pkgconfig
{
   my ( $method, $self, @args ) = @_;

   local $ENV{PKG_CONFIG_PATH} = "$libdir/pkgconfig/";
   open my $eupc, "-|", "pkg-config", "--define-variable=libdir=$libdir", "--$method", @args, $module or
      die "Cannot popen pkg-config - $!";

   my $ret = do { local $/; <$eupc> }; chomp $ret;

   return $ret;
}

sub libs
{
   # Append RPATH so that runtime linking actually works
   return _get_pkgconfig( libs => @_ ) . " -Wl,-R$libdir";
}

=head1 SEE ALSO

=over 4

=item *

L<https://github.com/mauke/unibilium> - mauke/unibilium on github

=back

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

=cut

0x55AA;
