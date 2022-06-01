// Generated from /Users/jumkey/IdeaProjects/dts/src/main/resources/DTS.g4 by ANTLR 4.10.1
// jshint ignore: start
import antlr4 from 'antlr4';
import DTSListener from './DTSListener.js';
import DTSVisitor from './DTSVisitor.js';

const serializedATN = [4,1,13,49,2,0,7,0,2,1,7,1,2,2,7,2,2,3,7,3,2,4,7,4,
1,0,1,0,1,0,1,0,1,1,1,1,5,1,17,8,1,10,1,12,1,20,9,1,1,1,1,1,1,2,1,2,1,2,
1,2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,3,2,38,8,2,1,3,1,3,1,3,4,3,43,
8,3,11,3,12,3,44,1,4,1,4,1,4,0,0,5,0,2,4,6,8,0,1,2,0,4,6,8,8,47,0,10,1,0,
0,0,2,14,1,0,0,0,4,37,1,0,0,0,6,39,1,0,0,0,8,46,1,0,0,0,10,11,5,13,0,0,11,
12,3,4,2,0,12,13,5,0,0,1,13,1,1,0,0,0,14,18,5,1,0,0,15,17,3,4,2,0,16,15,
1,0,0,0,17,20,1,0,0,0,18,16,1,0,0,0,18,19,1,0,0,0,19,21,1,0,0,0,20,18,1,
0,0,0,21,22,5,2,0,0,22,3,1,0,0,0,23,24,5,7,0,0,24,25,5,10,0,0,25,26,3,8,
4,0,26,27,5,11,0,0,27,38,1,0,0,0,28,29,5,7,0,0,29,30,5,10,0,0,30,31,3,6,
3,0,31,32,5,11,0,0,32,38,1,0,0,0,33,34,5,7,0,0,34,35,3,2,1,0,35,36,5,11,
0,0,36,38,1,0,0,0,37,23,1,0,0,0,37,28,1,0,0,0,37,33,1,0,0,0,38,5,1,0,0,0,
39,42,3,8,4,0,40,41,5,3,0,0,41,43,3,8,4,0,42,40,1,0,0,0,43,44,1,0,0,0,44,
42,1,0,0,0,44,45,1,0,0,0,45,7,1,0,0,0,46,47,7,0,0,0,47,9,1,0,0,0,3,18,37,
44];


const atn = new antlr4.atn.ATNDeserializer().deserialize(serializedATN);

const decisionsToDFA = atn.decisionToState.map( (ds, index) => new antlr4.dfa.DFA(ds, index) );

const sharedContextCache = new antlr4.PredictionContextCache();

export default class DTSParser extends antlr4.Parser {

    static grammarFileName = "DTS.g4";
    static literalNames = [ null, "'{'", "'}'", "','", null, null, null, 
                            null, null, null, "'='", "';'", "'/'" ];
    static symbolicNames = [ null, null, null, null, "STRING", "NUMBER2", 
                             "ARR", "KEY", "NUMBER", "WS", "EQ", "SEMICOLON", 
                             "ROOT", "VERSION" ];
    static ruleNames = [ "dts", "dic", "pair", "array", "value" ];

    constructor(input) {
        super(input);
        this._interp = new antlr4.atn.ParserATNSimulator(this, atn, decisionsToDFA, sharedContextCache);
        this.ruleNames = DTSParser.ruleNames;
        this.literalNames = DTSParser.literalNames;
        this.symbolicNames = DTSParser.symbolicNames;
    }

    get atn() {
        return atn;
    }



	dts() {
	    let localctx = new DtsContext(this, this._ctx, this.state);
	    this.enterRule(localctx, 0, DTSParser.RULE_dts);
	    try {
	        this.enterOuterAlt(localctx, 1);
	        this.state = 10;
	        this.match(DTSParser.VERSION);
	        this.state = 11;
	        this.pair();
	        this.state = 12;
	        this.match(DTSParser.EOF);
	    } catch (re) {
	    	if(re instanceof antlr4.error.RecognitionException) {
		        localctx.exception = re;
		        this._errHandler.reportError(this, re);
		        this._errHandler.recover(this, re);
		    } else {
		    	throw re;
		    }
	    } finally {
	        this.exitRule();
	    }
	    return localctx;
	}



	dic() {
	    let localctx = new DicContext(this, this._ctx, this.state);
	    this.enterRule(localctx, 2, DTSParser.RULE_dic);
	    var _la = 0; // Token type
	    try {
	        this.enterOuterAlt(localctx, 1);
	        this.state = 14;
	        this.match(DTSParser.T__0);
	        this.state = 18;
	        this._errHandler.sync(this);
	        _la = this._input.LA(1);
	        while(_la===DTSParser.KEY) {
	            this.state = 15;
	            this.pair();
	            this.state = 20;
	            this._errHandler.sync(this);
	            _la = this._input.LA(1);
	        }
	        this.state = 21;
	        this.match(DTSParser.T__1);
	    } catch (re) {
	    	if(re instanceof antlr4.error.RecognitionException) {
		        localctx.exception = re;
		        this._errHandler.reportError(this, re);
		        this._errHandler.recover(this, re);
		    } else {
		    	throw re;
		    }
	    } finally {
	        this.exitRule();
	    }
	    return localctx;
	}



	pair() {
	    let localctx = new PairContext(this, this._ctx, this.state);
	    this.enterRule(localctx, 4, DTSParser.RULE_pair);
	    try {
	        this.state = 37;
	        this._errHandler.sync(this);
	        var la_ = this._interp.adaptivePredict(this._input,1,this._ctx);
	        switch(la_) {
	        case 1:
	            this.enterOuterAlt(localctx, 1);
	            this.state = 23;
	            this.match(DTSParser.KEY);
	            this.state = 24;
	            this.match(DTSParser.EQ);
	            this.state = 25;
	            this.value();
	            this.state = 26;
	            this.match(DTSParser.SEMICOLON);
	            break;

	        case 2:
	            this.enterOuterAlt(localctx, 2);
	            this.state = 28;
	            this.match(DTSParser.KEY);
	            this.state = 29;
	            this.match(DTSParser.EQ);
	            this.state = 30;
	            this.array();
	            this.state = 31;
	            this.match(DTSParser.SEMICOLON);
	            break;

	        case 3:
	            this.enterOuterAlt(localctx, 3);
	            this.state = 33;
	            this.match(DTSParser.KEY);
	            this.state = 34;
	            this.dic();
	            this.state = 35;
	            this.match(DTSParser.SEMICOLON);
	            break;

	        }
	    } catch (re) {
	    	if(re instanceof antlr4.error.RecognitionException) {
		        localctx.exception = re;
		        this._errHandler.reportError(this, re);
		        this._errHandler.recover(this, re);
		    } else {
		    	throw re;
		    }
	    } finally {
	        this.exitRule();
	    }
	    return localctx;
	}



	array() {
	    let localctx = new ArrayContext(this, this._ctx, this.state);
	    this.enterRule(localctx, 6, DTSParser.RULE_array);
	    var _la = 0; // Token type
	    try {
	        this.enterOuterAlt(localctx, 1);
	        this.state = 39;
	        this.value();
	        this.state = 42; 
	        this._errHandler.sync(this);
	        _la = this._input.LA(1);
	        do {
	            this.state = 40;
	            this.match(DTSParser.T__2);
	            this.state = 41;
	            this.value();
	            this.state = 44; 
	            this._errHandler.sync(this);
	            _la = this._input.LA(1);
	        } while(_la===DTSParser.T__2);
	    } catch (re) {
	    	if(re instanceof antlr4.error.RecognitionException) {
		        localctx.exception = re;
		        this._errHandler.reportError(this, re);
		        this._errHandler.recover(this, re);
		    } else {
		    	throw re;
		    }
	    } finally {
	        this.exitRule();
	    }
	    return localctx;
	}



	value() {
	    let localctx = new ValueContext(this, this._ctx, this.state);
	    this.enterRule(localctx, 8, DTSParser.RULE_value);
	    var _la = 0; // Token type
	    try {
	        this.enterOuterAlt(localctx, 1);
	        this.state = 46;
	        _la = this._input.LA(1);
	        if(!((((_la) & ~0x1f) == 0 && ((1 << _la) & ((1 << DTSParser.STRING) | (1 << DTSParser.NUMBER2) | (1 << DTSParser.ARR) | (1 << DTSParser.NUMBER))) !== 0))) {
	        this._errHandler.recoverInline(this);
	        }
	        else {
	        	this._errHandler.reportMatch(this);
	            this.consume();
	        }
	    } catch (re) {
	    	if(re instanceof antlr4.error.RecognitionException) {
		        localctx.exception = re;
		        this._errHandler.reportError(this, re);
		        this._errHandler.recover(this, re);
		    } else {
		    	throw re;
		    }
	    } finally {
	        this.exitRule();
	    }
	    return localctx;
	}


}

DTSParser.EOF = antlr4.Token.EOF;
DTSParser.T__0 = 1;
DTSParser.T__1 = 2;
DTSParser.T__2 = 3;
DTSParser.STRING = 4;
DTSParser.NUMBER2 = 5;
DTSParser.ARR = 6;
DTSParser.KEY = 7;
DTSParser.NUMBER = 8;
DTSParser.WS = 9;
DTSParser.EQ = 10;
DTSParser.SEMICOLON = 11;
DTSParser.ROOT = 12;
DTSParser.VERSION = 13;

DTSParser.RULE_dts = 0;
DTSParser.RULE_dic = 1;
DTSParser.RULE_pair = 2;
DTSParser.RULE_array = 3;
DTSParser.RULE_value = 4;

class DtsContext extends antlr4.ParserRuleContext {

    constructor(parser, parent, invokingState) {
        if(parent===undefined) {
            parent = null;
        }
        if(invokingState===undefined || invokingState===null) {
            invokingState = -1;
        }
        super(parent, invokingState);
        this.parser = parser;
        this.ruleIndex = DTSParser.RULE_dts;
    }

	VERSION() {
	    return this.getToken(DTSParser.VERSION, 0);
	};

	pair() {
	    return this.getTypedRuleContext(PairContext,0);
	};

	EOF() {
	    return this.getToken(DTSParser.EOF, 0);
	};

	enterRule(listener) {
	    if(listener instanceof DTSListener ) {
	        listener.enterDts(this);
		}
	}

	exitRule(listener) {
	    if(listener instanceof DTSListener ) {
	        listener.exitDts(this);
		}
	}

	accept(visitor) {
	    if ( visitor instanceof DTSVisitor ) {
	        return visitor.visitDts(this);
	    } else {
	        return visitor.visitChildren(this);
	    }
	}


}



class DicContext extends antlr4.ParserRuleContext {

    constructor(parser, parent, invokingState) {
        if(parent===undefined) {
            parent = null;
        }
        if(invokingState===undefined || invokingState===null) {
            invokingState = -1;
        }
        super(parent, invokingState);
        this.parser = parser;
        this.ruleIndex = DTSParser.RULE_dic;
    }

	pair = function(i) {
	    if(i===undefined) {
	        i = null;
	    }
	    if(i===null) {
	        return this.getTypedRuleContexts(PairContext);
	    } else {
	        return this.getTypedRuleContext(PairContext,i);
	    }
	};

	enterRule(listener) {
	    if(listener instanceof DTSListener ) {
	        listener.enterDic(this);
		}
	}

	exitRule(listener) {
	    if(listener instanceof DTSListener ) {
	        listener.exitDic(this);
		}
	}

	accept(visitor) {
	    if ( visitor instanceof DTSVisitor ) {
	        return visitor.visitDic(this);
	    } else {
	        return visitor.visitChildren(this);
	    }
	}


}



class PairContext extends antlr4.ParserRuleContext {

    constructor(parser, parent, invokingState) {
        if(parent===undefined) {
            parent = null;
        }
        if(invokingState===undefined || invokingState===null) {
            invokingState = -1;
        }
        super(parent, invokingState);
        this.parser = parser;
        this.ruleIndex = DTSParser.RULE_pair;
    }

	KEY() {
	    return this.getToken(DTSParser.KEY, 0);
	};

	EQ() {
	    return this.getToken(DTSParser.EQ, 0);
	};

	value() {
	    return this.getTypedRuleContext(ValueContext,0);
	};

	SEMICOLON() {
	    return this.getToken(DTSParser.SEMICOLON, 0);
	};

	array() {
	    return this.getTypedRuleContext(ArrayContext,0);
	};

	dic() {
	    return this.getTypedRuleContext(DicContext,0);
	};

	enterRule(listener) {
	    if(listener instanceof DTSListener ) {
	        listener.enterPair(this);
		}
	}

	exitRule(listener) {
	    if(listener instanceof DTSListener ) {
	        listener.exitPair(this);
		}
	}

	accept(visitor) {
	    if ( visitor instanceof DTSVisitor ) {
	        return visitor.visitPair(this);
	    } else {
	        return visitor.visitChildren(this);
	    }
	}


}



class ArrayContext extends antlr4.ParserRuleContext {

    constructor(parser, parent, invokingState) {
        if(parent===undefined) {
            parent = null;
        }
        if(invokingState===undefined || invokingState===null) {
            invokingState = -1;
        }
        super(parent, invokingState);
        this.parser = parser;
        this.ruleIndex = DTSParser.RULE_array;
    }

	value = function(i) {
	    if(i===undefined) {
	        i = null;
	    }
	    if(i===null) {
	        return this.getTypedRuleContexts(ValueContext);
	    } else {
	        return this.getTypedRuleContext(ValueContext,i);
	    }
	};

	enterRule(listener) {
	    if(listener instanceof DTSListener ) {
	        listener.enterArray(this);
		}
	}

	exitRule(listener) {
	    if(listener instanceof DTSListener ) {
	        listener.exitArray(this);
		}
	}

	accept(visitor) {
	    if ( visitor instanceof DTSVisitor ) {
	        return visitor.visitArray(this);
	    } else {
	        return visitor.visitChildren(this);
	    }
	}


}



class ValueContext extends antlr4.ParserRuleContext {

    constructor(parser, parent, invokingState) {
        if(parent===undefined) {
            parent = null;
        }
        if(invokingState===undefined || invokingState===null) {
            invokingState = -1;
        }
        super(parent, invokingState);
        this.parser = parser;
        this.ruleIndex = DTSParser.RULE_value;
    }

	STRING() {
	    return this.getToken(DTSParser.STRING, 0);
	};

	NUMBER() {
	    return this.getToken(DTSParser.NUMBER, 0);
	};

	NUMBER2() {
	    return this.getToken(DTSParser.NUMBER2, 0);
	};

	ARR() {
	    return this.getToken(DTSParser.ARR, 0);
	};

	enterRule(listener) {
	    if(listener instanceof DTSListener ) {
	        listener.enterValue(this);
		}
	}

	exitRule(listener) {
	    if(listener instanceof DTSListener ) {
	        listener.exitValue(this);
		}
	}

	accept(visitor) {
	    if ( visitor instanceof DTSVisitor ) {
	        return visitor.visitValue(this);
	    } else {
	        return visitor.visitChildren(this);
	    }
	}


}




DTSParser.DtsContext = DtsContext; 
DTSParser.DicContext = DicContext; 
DTSParser.PairContext = PairContext; 
DTSParser.ArrayContext = ArrayContext; 
DTSParser.ValueContext = ValueContext; 
