#! /usr/bin/env false

use v6.c;

use Config;
use IRC::Client;

#| Implement an ignore list into IRC::Client.
class IRC::Client::Plugin::Ignore does IRC::Client::Plugin
{
	has Config $.config is rw; #= The global configuration object.

	my SetHash $nicks; #= Convenience SetHash of the ignored nicks.
	my SetHash $admins; #= Convenience SetHash for bot admins.

	subset Ignored where {
		$nicks{$_.nick}
	}

	subset Admin where {
		$admins{$_.nick}
	}

	method TWEAK
	{
		# Load the configuration into optimized SetHash objects.
		self!update-lists;
	}

	#| Ignore all channel notices from nicks on the ignore list.
	multi method irc-notice-channel(Ignored $e) { self!ignored($e) }

	#| Ignore all channel-wide messages from nicks on the ignore list.
	multi method irc-privmsg-channel(Ignored $e) { self!ignored($e) }

	#| Ignore all private messages from nicks on the ignore list.
	multi method irc-to-me(Ignored $e) { self!ignored($e) }

	#| Enable admins to add nicks to the ignore list.
	multi method irc-privmsg-channel(
		Admin $e where { $e ~~ /"{self.prefix}" ignore \s+ $<target>=\S+/ }
	) {
		self!add-ignore(~$<target>);
	}

	#| Enable admins to remove nicks from the ignore list.
	multi method irc-privmsg-channel(
		Admin $e where { $e ~~ /"{self.prefix}" unignore \s+ $<target>=\S+/ }
	) {
		self!remove-ignore(~$<target>)
	}

	#| Enable admins to add nicks to the ignore list via private messages.
	multi method irc-to-me(
		Admin $e where { $e ~~ /"{self.prefix}" ignore \s+ $<target>=\S+/ }
	) {
		self!add-ignore(~$<target>)
	}

	#| Enable admins to remove nicks from the ignore list.
	multi method irc-to-me(
		Admin $e where { $e ~~ /"{self.prefix}" unignore \s+ $<target>=\S+/ }
	) {
		self!remove-ignore(~$<target>)
	}

	#| A simple shortcut to the prefix used for commands.
	method prefix(
		--> Str
	) {
		$!config.get("bot.prefix", ".")
	}

	#| Add a nick to the ignore list. Returns a string based on whether it
	#| succeeded.
	method !add-ignore(
		Str:D $target,
		--> Str
	) {
		return "$target is already being ignored!" if $nicks{$target};

		$nicks{$target}++;

		"Added $target to the ignore list";
	}

	#| Output a debug message to STDERR when a message is being ignored and
	#| `debug` is set in the Config.
	method !ignored(
		IRC::Client::Message:D $e,
	) {
		note "{$e.nick} is being ignored" if $.config<debug>;

		Nil;
	}

	#| Check if the connection sending a given message is to be ignored.
	method !is-ignored(
		IRC::Client::Message:D $target,
		--> Bool
	) {
		$nicks{$target.nick};
	}

	#| Remove a nick to the ignore list. Returns a string based on whether it
	#| succeeded.
	method !remove-ignore(
		Str:D $target,
		--> Str
	) {
		return "$target is not being ignored!" unless $nicks{$target};

		$nicks{$target}--;

		"Removed $target from the ignore list";
	}

	#| Update the lists used throughout this module.
	method !update-lists()
	{
		$admins = $.config.get("admin.nicks", []).SetHash;
		$nicks = $.config.get("ignore.nicks", []).SetHash;
	}
}

# vim: ft=perl6 noet
