# Optional MCP adapter dependencies

The adapter is original Thistle code. It uses the official
[Model Context Protocol Ruby SDK](https://github.com/modelcontextprotocol/ruby-sdk/tree/v1.8.2)
as an external runtime dependency, pinned to `mcp = 1.8.2`. SDK source is not
vendored in this package. Its dependencies retain their own license and notices.
The adapter subclasses the SDK's stdio transport at the documented API seam;
see the [local Reader contract](docs/local-reader.md#sdk-fit-and-lifecycle).

The paired `thistle` Core gem contains the independently implemented Rust engine
and carries its own third-party notices and vendored dependency licenses. This
optional package does not include Woods engine or Map code.
