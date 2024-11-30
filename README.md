# lsptrace.nvim

A simple viewer for logs in [lsptrace format](https://github.com/mparq/lsptrace).

Example parsed viewer format looks like:
```
REQ--> [initialize] id=1  {"rootPath":"\/Users\/mparq\/code\/ext\/roslyn","capabilities":{"windo...
<--NTF [window/logMessage] {"type":3,"message":"[Program] Language server initialized"}
<--RSP 246ms [initialize] id=1  {"capabilities":{"codeLensProvider":{"resolveProvider":true},"re...
NTF--> [initialized] {}
NTF--> [workspace/didChangeConfiguration] {"settings":{"csharp|inlay_hints":{"dotnet_enable_inla...
NTF--> [solution/open] {"solution":"file:\/\/\/Users\/mparq\/code\/ext\/roslyn\/Roslyn.sln"}
NTF--> [textDocument/didOpen] {"textDocument":{"version":0,"languageId":"cs","text":"\/\/ Licens...
REQ--> [textDocument/documentHighlight] id=2  {"textDocument":{"uri":"file:\/\/\/Users\/mparq\/c...
<--REQ [workspace/configuration] id=2  {"items":[{"section":"csharp|symbol_search.dotnet_search_...
RSP--> 1ms [workspace/configuration] id=2  [null,null,null,null,null,null,null,null,null,null,nu...
<--REQ [client/registerCapability] id=3  {"registrations":[{"method":"textDocument\/diagnostic",...
RSP--> 0ms [client/registerCapability] id=3  null
<--REQ [workspace/configuration] id=4  {"items":[{"section":"csharp|symbol_search.dotnet_search_...
RSP--> 0ms [workspace/configuration] id=4  [null,null,null,null,null,null,null,null,null,null,nu...
<--NTF [window/logMessage] {"type":3,"message":"[LanguageServerProjectSystem] Loading \/Users\/m...
<--RSP 388ms [textDocument/documentHighlight] id=2  []
<--REQ [client/registerCapability] id=5  {"registrations":[{"method":"workspace\/didChangeWatche...
RSP--> 2ms [client/registerCapability] id=5  null
<--REQ [client/registerCapability] id=6  {"registrations":[{"method":"workspace\/didChangeWatche...
<--REQ [client/registerCapability] id=7  {"registrations":[{"method":"workspace\/didChangeWatche...
RSP--> 0ms [client/registerCapability] id=6  null
RSP--> 1ms [client/registerCapability] id=7  null
<--REQ [client/registerCapability] id=8  {"registrations":[{"method":"workspace\/didChangeWatche...
RSP--> 0ms [client/registerCapability] id=8  null
<--REQ [client/registerCapability] id=9  {"registrations":[{"method":"workspace\/didChangeWatche...
<--REQ [client/registerCapability] id=10  {"registrations":[{"method":"workspace\/didChangeWatch...
<--REQ [client/registerCapability] id=11  {"registrations":[{"method":"workspace\/didChangeWatch...
<--REQ [client/registerCapability] id=12  {"registrations":[{"method":"workspace\/didChangeWatch...
<--REQ [client/registerCapability] id=13  {"registrations":[{"method":"workspace\/didChangeWatch...
<--REQ [client/registerCapability] id=14  {"registrations":[{"method":"workspace\/didChangeWatch...
<--REQ [client/registerCapability] id=15  {"registrations":[{"method":"workspace\/didChangeWatch...
<--REQ [client/registerCapability] id=16  {"registrations":[{"method":"workspace\/didChangeWatch...
<--REQ [client/registerCapability] id=17  {"registrations":[{"method":"workspace\/didChangeWatch...
RSP--> 0ms [client/registerCapability] id=9  null
RSP--> 1ms [client/registerCapability] id=10  null
RSP--> 1ms [client/registerCapability] id=11  null
RSP--> 2ms [client/registerCapability] id=12  null
RSP--> 2ms [client/registerCapability] id=13  null
RSP--> 3ms [client/registerCapability] id=14  null
RSP--> 4ms [client/registerCapability] id=15  null
RSP--> 4ms [client/registerCapability] id=16  null

```

## Usage

Install plugin `mparq/lsptrace`.

Setup creates the `:LSPTraceView` (ignore `:LSPTraceShowFullLine` for now, I don't know how to do plugins well) which you can run while viewing a `.lsptrace` file to open up a buffer
from the contents of that file which contains a helpful, parsed representation of the lsptrace.

The plugin right now directly sets up the following maps:
- `<TAB>` when cursor is on a line to open up the full raw lsptrace message in a popup window. `<TAB>` again closes the window.
- `q` to exit the buffer.

Right now, I've only tested by viewing one buffer at a time, viewing multiple may break as the plugin manages a global state of trace lines.
