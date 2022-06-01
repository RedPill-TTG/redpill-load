// jshint ignore: start
import TokenStreamRewriter from './antlr4/TokenStreamRewriter';
import DTSListener from './DTSListener.js';
import DTSParser from "./DTSParser";

// This class defines a complete listener for a parse tree produced by DTSParser.
export default class MyDTSListener extends DTSListener {

    static tokens;
    static rewriter;


    constructor(tokens) {
        super();
        this.tokens = tokens;
        this.rewriter = new TokenStreamRewriter(tokens);
    }

    // Enter a parse tree produced by DTSParser#dts.
    enterDts(ctx) {
    }

    // Exit a parse tree produced by DTSParser#dts.
    exitDts(ctx) {
    }


    // Enter a parse tree produced by DTSParser#dic.
    enterDic(ctx) {
    }

    // Exit a parse tree produced by DTSParser#dic.
    exitDic(ctx) {
    }


    // Enter a parse tree produced by DTSParser#pair.
    enterPair(ctx) {
    }

    // Exit a parse tree produced by DTSParser#pair.
    exitPair(ctx) {
    }


    // Enter a parse tree produced by DTSParser#array.
    enterArray(ctx) {
    }

    // Exit a parse tree produced by DTSParser#array.
    exitArray(ctx) {
    }


    // Enter a parse tree produced by DTSParser#value.
    enterValue(ctx) {
    }

    // Exit a parse tree produced by DTSParser#value.
    exitValue(ctx) {
    }

    tabCnt = 0;
    lastKey = "";
    map = new Map();

    visitTerminal(node) {
        if (node.getSymbol().type === DTSParser.T__0) {// {
            this.tabCnt++;
        }
        if (node.getSymbol().type === DTSParser.T__1) {// }
            this.tabCnt--;
        }
        if (node.getSymbol().type === DTSParser.KEY || node.getSymbol().type === DTSParser.T__1) {
            this.rewriter.insertBefore(node.getSymbol(), "\t".repeat(Math.max(0, this.tabCnt)));
        }
        if (node.getSymbol().type === DTSParser.SEMICOLON
            || node.getSymbol().type === DTSParser.T__0
            || node.getSymbol().type === DTSParser.VERSION) {
            this.rewriter.insertAfter(node.getSymbol(), "\n");
        }
        if (node.getSymbol().type === DTSParser.KEY || node.getSymbol().type === DTSParser.EQ) {
            this.rewriter.insertAfter(node.getSymbol(), " ");
        }

        if (node.getSymbol().type === DTSParser.KEY) {
            if (node.getText() === "/") {
                this.lastKey = "/";
            } else {
                this.lastKey += "/" + node.getText();
            }
            this.map.set(this.lastKey.replace("//", "/"), node.getSymbol().tokenIndex);
        }
        if (node.getSymbol().type === DTSParser.SEMICOLON) {
            this.lastKey = this.lastKey.substring(0, this.lastKey.lastIndexOf('/'));
        }
        super.visitTerminal(node);
    }

    put(path, value) {
        let x = this.map.get(path);
        console.log("modify path " + path);
        if (x == null) {
            console.log("[err] path not found");
        } else if (this.tokens.get(x + 1).type === DTSParser.EQ) {
            let token = this.tokens.get(x + 2);
            console.log("[ok] value " + value);
            this.rewriter.replaceSingle(token, value);
            return 1;
        } else {
            console.log("[err] path not correct");
        }
        return 0;
    }

}
