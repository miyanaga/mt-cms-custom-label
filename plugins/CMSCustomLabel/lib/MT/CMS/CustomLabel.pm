package MT::CMS::CustomLabel;

use utf8;
use strict;
use JSON;

my $SHORT = 48;

# Dummy callback to load this module
sub init_app { 1 }

{
    sub replace_words {
        my ( $rphrase ) = @_;
        my $app = MT->app;
        
        # Only CMS and, in blog or website context.
        return unless $app->isa('MT::App::CMS');
        return unless $app->can('blog');
        my $blog = $app->blog || return;
        my $request = $app->request || return;
        
        # Request cache
        my $cache = $request->cache('CMSCustomLabel');
        $request->cache('CMSCustomLabel', $cache ||= {});
        my $blog_cache = $cache->{$blog->id} ||= { shorts => {} };
    
        # Use cache for short phrase
        my $orig;
        if ( length($$rphrase) < $SHORT ) {
            $orig = $$rphrase;
            if ( defined ( my $cached = $blog_cache->{shorts}->{$$rphrase} ) ) {
                $$rphrase = $cached;
                return;
            }
        }
        
        # Get and cache dictionary from config
        my $dic = $blog_cache->{dic};
        unless ( defined $dic ) {
            my %config;
            my $plugin = MT->component('CMSCustomLabel') || return;
            $plugin->load_config(\%config, 'blog:' . $blog->id);
            my $dic = eval { from_json($config{dictionary}) } || return;
            my $rows = $dic->{rows} || return;
            
            # FIXME rows maybe store as a string by ko.mapping plugin.
            # Perhaps depends on jQuery version.
            $rows = eval { from_json($rows) } unless ref $rows;
            return unless ref $rows eq 'ARRAY';
            
            # Cache the dictionary
            my $from = join('|', map { quotemeta($_) } sort { $b cmp $a } grep { $_ } map { $_->{f} } @$rows);
            my %to = map { $_->{f} => $_->{t} } grep { $_->{f} } @$rows;
            $dic = $blog_cache->{dic} = {
                from  => qr!$from!,
                to    => \%to,
            };
        }
        
        # Replace about word pairs
        my $from = $dic->{from} || return;
        my $to = $dic->{to} || return;
        $$rphrase =~ s!$from!{ $to->{$&} || '' }!eg;
        
        # Cache if short phrase
        $blog_cache->{shorts}->{$orig} = $$rphrase if $orig;
    }

    no warnings qw(redefine);
    
    # Override translaters
    my $__mt_translate = \&MT::translate;
    *MT::translate = sub {
        my $phrase = $__mt_translate->(@_);
        replace_words(\$phrase);
        $phrase;
    };

    my $__component_translate = \&MT::Component::translate;
    *MT::Component::translate = sub {
        my ( $component ) = @_;
        my $phrase = $__component_translate->(@_);
        
        # Except for this plugin
        return $phrase
            if $component->{id} && $component->{id} eq 'cmscustomlabel';

        replace_words(\$phrase);
        $phrase;
    };
}

1;
__END__