# Route constraint observation

The observer reads the already supplied route set, without recognizing a request
or calling constraint objects. Rails 8.1.4 exposes request conditions on Journey
routes and path segment requirements separately. Rails' mapper constraint wrapper
is a `:nodoc:` internal; its shape is checked only for Rails 8.1.4. Other Rails
versions and unrecognized endpoint types report unknown, not an absence of rules.
The Rails routing guide documents request, segment, and advanced constraints but
does not offer a public enumeration interface for opaque wrapper contents.

Entries are limited to 32 per family and 8192 encoded JSON bytes per family.
Strings and regular expressions carry their source encoding; regular expressions
also carry their options and expression encoding. Values that cannot be safely
represented, oversized families, and inspection errors are unknown. Other value
types are opaque and are never formatted or traversed. The existing combined fact
evidence budget still applies. Route order remains part of identity, and the full
fact participates in generation identity. Presence is not proof of a match.

Map treats saved attributes as untrusted input, including snapshots from other
producers. Before formatting, it separately checks the supported metadata shape,
plain value types, canonical encoding names, unsigned 32-bit regexp options and
the same 32-entry/8192-byte complete JSON-array limits for each family. Malformed
or oversized metadata displays an explicit unknown state. These display limits
do not change native snapshot validation or imply that producer checks ran.
Quoted values preserve whitespace and show escaped controls. Regexp flags have
plain-language descriptions alongside their exact numeric options. Find omits
the condition column when no route appears in its results.

Reconsider the version boundary only with real RouteSet tests and review of the
corresponding Rails internals. This narrow observation does not qualify L02.
