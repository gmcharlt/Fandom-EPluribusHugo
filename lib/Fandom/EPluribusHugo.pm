package Fandom::EPluribusHugo;

use warnings;
use strict;
use Carp;

use version;
our $VERSION = qv('0.0.2');

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
            # If elimination would reduce the number of finalists to
            # fewer than the number specified in section 3.8.1, then
            # instead no nominees will be eliminated during that
            # round, and all remaining nominees shall appear on the
            # final ballot, extending it if necessary.
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

    ##
    ## Calculation phase
    ##

    # number of ballots on which each nominee appears
    my %total_nominations = map { $_ => 0 } @$surviving_nominees;
    # points accumulated by each nominee
    my %points = map { $_ => 0 } @$surviving_nominees; 

    foreach my $ballot ($self->ballots()) {
        my @active_nominations = ();
        foreach my $nominee (@$ballot) {
            push @active_nominations, $nominee if exists($total_nominations{$nominee});
        }
        if (0 == @active_nominations) {
            # ballot doesn't name any of the surviving nominees, so
            # it can have no further influence on the results
            next;
        }

        # First, the total number of nominations (the number of ballots
        # on which each nominee appears) from all eligible ballots
        # shall be tallied for each remaining nominee.
        $total_nominations{$_}++ foreach @active_nominations;

        # [A] single "point" shall be assigned to each nomination ballot.
        # That point shall be equally divided among all remaining nominees
        # on that ballot.
        my $points_per_nomination = 1 / scalar(@active_nominations);
        $points{$_} += $points_per_nomination foreach @active_nominations;
    }

    ##
    ## Selection phase
    ##

    # sort by ascending point totals
    my @sorted_by_points = sort { $points{$a} <=> $points{$b} } keys %points;

    # The two nominees with the lowest point totals shall be selected
    # for comparison in the Elimination Phase.
    my @candidates = @sorted_by_points[0..1];

    # Now check for ties...

    my $threshold;
    if      ($points{ $candidates[0] } == $points{ $candidates[1] }) {
        # During the Selection Phase, if two or more nominees are tied
        # for the lowest point total, all such nominees shall be
        # selected for the Elimination Phase.
        $threshold = $points{ $candidates[0] };
    } elsif ($points{ $candidates[1] } == $points{ $sorted_by_points[2] }) {
        # During the Selection Phase, if one nominee has the lowest
        # point total and two or more nominees are tied for the
        # second-lowest point total, then all such nominees shall be
        # selected for the Elimination Phase.
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

    ##
    ## Elimination phase
    ##

    my @eliminated = ();
    my @sorted_by_nominations =
        sort { $total_nominations{$a} <=> $total_nominations{$b} }
        @candidates;
    foreach my $candidate (@sorted_by_nominations) {
        if (@eliminated) {
            if ($total_nominations{ $candidate } > $total_nominations{ $eliminated[0] }) {
                # Nominees chosen in the Selection Phase shall be
                # compared, and the nominee with the fewest number
                # of nominations shall be eliminated and removed from
                # all ballots for the Calculation Phase of all
                # subsequent rounds. (See 3.A.3 for ties.)
                last;
            } elsif ($points{ $candidate } >  $points{ $eliminated[0] }) {
                # During the Elimination Phase, if two or more nominees
                # are tied for the fewest number of nominations, the
                # nominee with the lowest point total at that round
                # shall be eliminated.
                last;
            } elsif ($points{ $candidate } == $points{ $eliminated[0] }) {
                # During the Elimination Phase, if two or morenominees
                # are tied for both fewest number of nominations and
                # lowest point total, then all such nominees tied at
                # that round shall be eliminated.
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
