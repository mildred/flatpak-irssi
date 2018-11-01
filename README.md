flatpak-irssi
=============

irssi flatpak

Build
-----

    flatpak-builder --repo=repo --force-clean build fr.mildred.irssi.json

Install
-------

    flatpak --user remote-add --no-gpg-verify local-irssi repo
    flatpak install -y --reinstall local-irssi fr.mildred.irssi

Add CPAN Perl modules
---------------------

    ./cpan-flatpak.sh My::Perl::Module

Then add the files appearing in `My::Perl::Module.deps` in your Flatpak manifest.

Be careful that on CPAN if two releases provides the same module, which module is configured depends on the metacpan server.
