# Table of Contents

- [Table of Contents](#table-of-contents)
- [NC Issues](#nc-issues)
  - [NC-1: Functions not used internally could be marked external](#nc-1-functions-not-used-internally-could-be-marked-external)
  - [NC-2: Constants should be defined and used instead of literals](#nc-2-constants-should-be-defined-and-used-instead-of-literals)
  - [NC-3: Event is missing `indexed` fields](#nc-3-event-is-missing-indexed-fields)
# NC Issues

<a name="NC-1"></a>
## NC-1: Functions not used internally could be marked external

- Found in src/TSwapPool.sol: 11477:809:10
- Found in src/TSwapPool.sol: 2948:239:10

<a name="NC-2"></a>
## NC-2: Constants should be defined and used instead of literals

- Found in src/TSwapPool.sol: 10891:3:10
- Found in src/TSwapPool.sol: 11009:4:10
- Found in src/TSwapPool.sol: 15424:4:10
- Found in src/TSwapPool.sol: 15646:4:10
- Found in src/TSwapPool.sol: 11416:5:10
- Found in src/TSwapPool.sol: 11460:3:10


<a name="NC-3"></a>
## NC-3: Event is missing `indexed` fields

Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

- Found in src/PoolFactory.sol: 1307:61:31
- Found in src/TSwapPool.sol: 1897:108:10
- Found in src/TSwapPool.sol: 2010:110:10
- Found in src/TSwapPool.sol: 2125:116:10


