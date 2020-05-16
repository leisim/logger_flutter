part of logger_flutter;

ListQueue<OutputEvent> _outputEventBuffer = ListQueue();
int _bufferSize = 20;
bool _initialized = false;

class LogConsole extends StatefulWidget {
  final bool dark;
  final bool showCloseButton;
  final List<Level> levelsToFilter;
  final Level defaultLevel;
  final double lineWidth;

  LogConsole({
    this.dark = false,
    this.showCloseButton = false,
    List<Level> levelsToFilter,
    Level defaultLevel,
    this.lineWidth = 1600,
  })  : levelsToFilter =
            levelsToFilter ?? const [Level.verbose, Level.debug, Level.info, Level.warning, Level.error, Level.wtf],
        defaultLevel = defaultLevel ?? Level.verbose,
        assert(_initialized, "Please call LogConsole.init() first.");

  static void init({int bufferSize = 20}) {
    if (_initialized) return;

    _bufferSize = bufferSize;
    _initialized = true;
    Logger.addOutputListener((e) {
      if (_outputEventBuffer.length == bufferSize) {
        _outputEventBuffer.removeFirst();
      }
      _outputEventBuffer.add(e);
    });
  }

  @override
  _LogConsoleState createState() => _LogConsoleState();
}

class RenderedEvent {
  final int id;
  final Level level;
  final TextSpan span;
  final String lowerCaseText;

  RenderedEvent(this.id, this.level, this.span, this.lowerCaseText);
}

class _LogConsoleState extends State<LogConsole> {
  OutputCallback _callback;

  ListQueue<RenderedEvent> _renderedBuffer = ListQueue();
  List<RenderedEvent> _filteredBuffer = [];

  var _scrollController = ScrollController();
  var _filterController = TextEditingController();

  Level _filterLevel;
  double _logFontSize = 14;

  var _currentId = 0;
  bool _scrollListenerEnabled = true;
  bool _followBottom = true;

  final _mapLevelText = {
    Level.verbose: 'VERBOSE',
    Level.debug: 'DEBUG',
    Level.info: 'INFO',
    Level.warning: 'WARNING',
    Level.error: 'ERROR',
    Level.wtf: 'WTF',
  };

  @override
  void initState() {
    super.initState();

    _filterLevel = widget.defaultLevel;

    _callback = (e) {
      if (_renderedBuffer.length == _bufferSize) {
        _renderedBuffer.removeFirst();
      }

      _renderedBuffer.add(_renderEvent(e));
      _refreshFilter();
    };

    Logger.addOutputListener(_callback);

    _scrollController.addListener(() {
      if (!_scrollListenerEnabled) return;
      var scrolledToBottom = _scrollController.offset >=
          _scrollController.position.maxScrollExtent;
      setState(() {
        _followBottom = scrolledToBottom;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _renderedBuffer.clear();
    for (var event in _outputEventBuffer) {
      _renderedBuffer.add(_renderEvent(event));
    }
    _refreshFilter();
  }

  void _refreshFilter() {
    var newFilteredBuffer = _renderedBuffer.where((it) {
      var logLevelMatches = it.level.index >= _filterLevel.index;
      if (!logLevelMatches) {
        return false;
      } else if (_filterController.text.isNotEmpty) {
        var filterText = _filterController.text.toLowerCase();
        return it.lowerCaseText.contains(filterText);
      } else {
        return true;
      }
    }).toList();
    setState(() {
      _filteredBuffer = newFilteredBuffer;
    });

    if (_followBottom) {
      Future.delayed(Duration.zero, _scrollToBottom);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: widget.dark
          ? ThemeData(
              brightness: Brightness.dark,
              accentColor: Colors.blueGrey,
            )
          : ThemeData(
              brightness: Brightness.light,
              accentColor: Colors.lightBlueAccent,
            ),
      home: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildTopBar(),
              Expanded(
                child: _buildLogContent(),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
        floatingActionButton: AnimatedOpacity(
          opacity: _followBottom ? 0 : 1,
          duration: Duration(milliseconds: 150),
          child: Padding(
            padding: EdgeInsets.only(bottom: 60),
            child: FloatingActionButton(
              mini: true,
              clipBehavior: Clip.antiAlias,
              child: Icon(
                Icons.arrow_downward,
                color: widget.dark ? Colors.white : Colors.lightBlue[900],
              ),
              onPressed: _scrollToBottom,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogContent() {
    final elements = ListView.builder(
      shrinkWrap: true,
      controller: _scrollController,
      itemBuilder: (context, index) {
        var logEntry = _filteredBuffer[index];
        return Text.rich(
          logEntry.span,
          key: Key(logEntry.id.toString()),
          style: TextStyle(fontSize: _logFontSize),
        );
      },
      itemCount: _filteredBuffer.length,
    );

    final child = widget.lineWidth != null && widget.lineWidth > 0
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: widget.lineWidth,
              child: elements,
            ),
          )
        : elements;

    return Container(
      color: widget.dark ? Colors.black : Colors.grey[150],
      child: child,
    );
  }

  Widget _buildTopBar() {
    return LogBar(
      dark: widget.dark,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          Text(
            "Log Console",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Spacer(),
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              setState(() {
                _logFontSize++;
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.remove),
            onPressed: () {
              setState(() {
                _logFontSize--;
              });
            },
          ),
          if (widget.showCloseButton)
            IconButton(
              icon: Icon(Icons.close),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return LogBar(
      dark: widget.dark,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          Expanded(
            child: TextField(
              style: TextStyle(fontSize: 20),
              controller: _filterController,
              onChanged: (s) => _refreshFilter(),
              decoration: InputDecoration(
                labelText: "Filter log output",
                border: OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(width: 20),
          DropdownButton(
            value: _filterLevel,
            items: [
              for (final level in widget.levelsToFilter)
                DropdownMenuItem(
                  child: Text(_mapLevelText[level]),
                  value: level,
                ),
            ],
            onChanged: (value) {
              _filterLevel = value;
              _refreshFilter();
            },
          )
        ],
      ),
    );
  }

  void _scrollToBottom() async {
    _scrollListenerEnabled = false;

    setState(() {
      _followBottom = true;
    });

    var scrollPosition = _scrollController.position;
    await _scrollController.animateTo(
      scrollPosition.maxScrollExtent,
      duration: new Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );

    _scrollListenerEnabled = true;
  }

  RenderedEvent _renderEvent(OutputEvent event) {
    var parser = AnsiParser(widget.dark);
    var text = event.lines.join('\n');
    parser.parse(text);
    return RenderedEvent(
      _currentId++,
      event.level,
      TextSpan(children: parser.spans),
      text.toLowerCase(),
    );
  }

  @override
  void dispose() {
    Logger.removeOutputListener(_callback);
    super.dispose();
  }
}

class LogBar extends StatelessWidget {
  final bool dark;
  final Widget child;

  LogBar({this.dark, this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            if (!dark)
              BoxShadow(
                color: Colors.grey[400],
                blurRadius: 3,
              ),
          ],
        ),
        child: Material(
          color: dark ? Colors.blueGrey[900] : Colors.white,
          child: Padding(
            padding: EdgeInsets.fromLTRB(15, 8, 15, 8),
            child: child,
          ),
        ),
      ),
    );
  }
}
