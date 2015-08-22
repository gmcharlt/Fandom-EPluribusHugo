package Fandom::EPluribusHugo;

use warnings;
use strict;
use Carp;

use version;
our $VERSION = qv('0.0.1');

sub new {
    my $class = shift;

    my $self = {
        max_finalists              => 5,
        max_nominations_per_ballot => 5,
        nominees   => [],
        ballots => [],
        round_results => [],
    };
    return bless $self, $class;
}

# accessor for list of all nominees nominated
sub nominees {
    my $self = shift;
    my @nominees = @_;

    if (scalar @nominees) {
        $self->{nominees} = [ @nominees ]
    } else {
        return @{ $self->{nominees} };
    }
}

# accessor for list of ballots, which should
# be an array of arrayrefs
sub ballots {
    my $self = shift;
    my @ballots = @_;

    if (scalar @ballots) {
        $self->{ballots} = [ @ballots ];
    } else {
        return @{ $self->{ballots} };
    }
}

sub calculate_finalists {
    my $self = shift;

    my $surviving_nominees = [ $self->nominees() ];
    my $round = 1;
    while (1) {
        my ($eliminated, $points, $total_nominations) =
            $self->_run_elimination_round($surviving_nominees);
        if ((@$surviving_nominees - @$eliminated) >= $self->{max_finalists}) {
            my %to_remove = map { $_ => 1 } @$eliminated;
            @$surviving_nominees =
                grep { !exists($to_remove{$_}) }
                @$surviving_nominees;

            push @{ $self->{round_results} }, {
                points => $points,
                total_nominations => $total_nominations,
                eliminated => $eliminated,
            };
        } else {
            push @{ $self->{round_results} }, {
                points => $points,
                total_nominations => $total_nominations,
                final_ballot => $surviving_nominees,
            };
            last;
        }
        $round++;
    }

    return @$surviving_nominees;
}

sub _run_elimination_round {
    my $self = shift;
    my $surviving_nominees = shift;

    # Calculation phase
    my %total_nominations = map { $_ => 0 } @$surviving_nominees;
    my %points = map { $_ => 0 } @$surviving_nominees; 
    foreach my $ballot ($self->ballots()) {
        my @active_nominations = ();
        foreach my $nominee (@$ballot) {
            push @active_nominations, $nominee if exists($total_nominations{$nominee});
        }
        if (0 == @active_nominations) {
            next;
        }
        my $points_per_nomination = 1 / scalar(@active_nominations);
        $total_nominations{$_}++ foreach @active_nominations;
        $points{$_} += $points_per_nomination foreach @active_nominations;
    }

    ##
    ## Selection phase
    ##

    my @sorted_by_points = sort { $points{$a} <=> $points{$b} } keys %points;

    # will have at least two entries for the elimination phase
    my @candidates = @sorted_by_points[0..1];

    # and may have more if there's a tie for the lowest number of points
    my $threshold;
    if      ($points{ $candidates[0] } == $points{ $candidates[1] }) {
        $threshold = $points{ $candidates[0] };
    } elsif ($points{ $candidates[1] } == $points{ $sorted_by_points[2] }) {
        $threshold = $points{ $candidates[1] };
    }

    if (defined $threshold) {
        for (my $i = 2; $i <= $#sorted_by_points; $i++) {
            if ($points{$sorted_by_points[$i]} == $threshold) {
                push @candidates, $sorted_by_points[$i];
            } else {
                last;
            }
        }
    }

    # Elimination phase
    my @eliminated = ();
    my @sorted_by_nominations =
        sort { $total_nominations{$a} <=> $total_nominations{$b} }
        @candidates;
    foreach my $candidate (@sorted_by_nominations) {
        if (@eliminated) {
            if ($total_nominations{ $candidate } > $total_nominations{ $eliminated[0] }) {
                last;
            } elsif ($points{ $candidate } == $points{ $eliminated[0] }) {
                push @eliminated, $candidate;
            } 
        } else {
            push @eliminated, $candidate;
        }
    }

    return (\@eliminated, \%points, \%total_nominations);
}

sub round_details {
    my $self = shift;
    return @{ $self->{round_results} };
}

1; # Magic true value required at end of module
__END__

=head1 NAME

Fandom::EPluribusHugo - SDV-LPE Hugo nomination tabulator


=head1 VERSION

This document describes Fandom::EPluribusHugo version 0.0.1


=head1 SYNOPSIS

    use Fandom::EPluribusHugo;
    
    my $tabulator = Fandom::EPluribusHugo->new();
    # load list of nominees
    $tabulator->nominees(@nominees);
    # load list of nomination ballots
    $tabulator->ballots(@ballots);
    # calculate list of finalists
    my @finalists = $tabulator->calculate_finalists();
    # get details on the results of each round
    my @round_details = $tabulator->round_details();
  
=head1 DESCRIPTION

The Fandom::EPluribusHugo module implements the SDV-LPE
(single divisible vote with least popular eliminated) algorithm
for calculating Hugo finalists from a set of nominating ballots
as described at L<http://sasquan.org/business-meeting/agenda/#epluribus>.

=head1 DEPENDENCIES

None.

=head1 AUTHOR

Galen Charlton  C<< <gmcharlt@gmail.com> >>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2015, Galen Charlton C<< <gmcharlt@gmail.com> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
