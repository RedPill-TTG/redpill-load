import antlr4 from 'antlr4';

// TODO: run this through eslint
export default class TokenStreamRewriter {
    static DEFAULT_PROGRAM_NAME = "default";

    /**
     * @param {import("./CommonTokenStream")} tokens
     */
    constructor(tokens) {
        this.tokens = tokens;
        this.programs = new Map();
    }

    getTokenStream() {
        return this.tokens;
    }

    insertAfter(tokenOrIndex, text, programName = TokenStreamRewriter.DEFAULT_PROGRAM_NAME) {
        let index;
        if (typeof tokenOrIndex === "number") {
            index = tokenOrIndex;
        } else {
            index = tokenOrIndex.tokenIndex;
        }

        // to insert after, just insert before next index (even if past end)
        let rewrites = this.getProgram(programName);
        let op = new InsertAfterOp(this.tokens, index, rewrites.length, text);
        rewrites.push(op);
    }

    insertBefore(tokenOrIndex, text, programName = TokenStreamRewriter.DEFAULT_PROGRAM_NAME) {
        let index;
        if (typeof tokenOrIndex === "number") {
            index = tokenOrIndex;
        } else {
            index = tokenOrIndex.tokenIndex;
        }

        const rewrites = this.getProgram(programName);
        const op = new InsertBeforeOp(this.tokens, index, rewrites.length, text);
        rewrites.push(op);
    }

    replaceSingle(index, text) {
        if (typeof index === "number") {
            this.replace(index, index, text);
        }
        else {
            // Wait, this is exactly as the line above
            this.replace(index, index, text);
        }
    }

    replace(from, to, text, programName = TokenStreamRewriter.DEFAULT_PROGRAM_NAME) {
        // TODO, test with tokens? Do they have a tokenIndex attribute?
        if (typeof from !== "number") {
            from = from.tokenIndex;
        }
        if (typeof to !== "number") {
            to = to.tokenIndex;
        }
        if (from > to || from < 0 || to < 0 || to >= this.tokens.tokens.length) {
            throw new RangeError(`replace: range invalid: ${from}..${to}(size=${this.tokens.tokens.length})`);
        }
        let rewrites = this.getProgram(programName);
        let op = new ReplaceOp(this.tokens, from, to, rewrites.length, text);
        rewrites.push(op);
    }

    delete(from, to, programName = TokenStreamRewriter.DEFAULT_PROGRAM_NAME) {
        if (typeof to === "undefined") {
            to = from;
        }
        if (typeof from === "number") {
            this.replace(from, to, "", programName);
        }
        else {
            this.replace(from, to, "", programName);
        }
    }

    getProgram(name) {
        let is = this.programs.get(name);
        if (is == null) {
            is = this.initializeProgram(name);
        }
        return is;
    }

    initializeProgram(name) {
        const is = [];
        this.programs.set(name, is);
        return is;
    }

    /**
     *
     * @param {Interval | string} [intervalOrProgram]
     * @param {string} [programName]
     * @returns
     */
    getText(intervalOrProgram, programName = TokenStreamRewriter.DEFAULT_PROGRAM_NAME) {
        let interval;
        if (intervalOrProgram instanceof antlr4.Interval) {
            interval = intervalOrProgram;
        } else {
            interval = new antlr4.Interval(0, this.tokens.tokens.length - 1);
        }

        if (typeof intervalOrProgram === "string") {
            programName = intervalOrProgram;
        }

        const rewrites = this.programs.get(programName);
        let start = interval.start;
        let stop = interval.stop;

        // ensure start/end are in range
        if (stop > this.tokens.tokens.length - 1) {
            stop = this.tokens.tokens.length - 1;
        }
        if (start < 0) {
            start = 0;
        }

        if (rewrites == null || rewrites.length === 0) {
            return this.tokens.getText(interval); // no instructions to execute
        }

        let buf = [];

        // First, optimize instruction stream
        let indexToOp = this.reduceToSingleOperationPerIndex(rewrites);

        // Walk buffer, executing instructions and emitting tokens
        let i = start;
        while (i <= stop && i < this.tokens.tokens.length) {
            let op = indexToOp.get(i);
            indexToOp.delete(i); // remove so any left have index size-1
            let t = this.tokens.get(i);
            if (op == null) {
                // no operation at that index, just dump token
                if (t.type !== antlr4.Token.EOF) {
                    buf.push(String(t.text));
                }
                i++; // move to next token
            }
            else {
                i = op.execute(buf); // execute operation and skip
            }
        }

        // include stuff after end if it's last index in buffer
        // So, if they did an insertAfter(lastValidIndex, "foo"), include
        // foo if end==lastValidIndex.
        if (stop === this.tokens.tokens.length - 1) {
            // Scan any remaining operations after last token
            // should be included (they will be inserts).
            for (const op of indexToOp.values()) {
                if (op.index >= this.tokens.tokens.length - 1) {
                    buf.push(op.text.toString());
                }
            }
        }

        return buf.join("");
    }

    reduceToSingleOperationPerIndex(rewrites) {
        // WALK REPLACES
        for (let i = 0; i < rewrites.length; i++) {
            let op = rewrites[i];
            if (op == null) {
                continue;
            }
            if (!(op instanceof ReplaceOp)) {
                continue;
            }
            let rop = op;
            // Wipe prior inserts within range
            let inserts = this.getKindOfOps(rewrites, InsertBeforeOp, i);
            for (let iop of inserts) {
                if (iop.index === rop.index) {
                    // E.g., insert before 2, delete 2..2; update replace
                    // text to include insert before, kill insert
                    rewrites[iop.instructionIndex] = undefined;
                    rop.text = iop.text.toString() + (rop.text != null ? rop.text.toString() : "");
                }
                else if (iop.index > rop.index && iop.index <= rop.lastIndex) {
                    // delete insert as it's a no-op.
                    rewrites[iop.instructionIndex] = undefined;
                }
            }
            // Drop any prior replaces contained within
            let prevReplaces = this.getKindOfOps(rewrites, ReplaceOp, i);
            for (let prevRop of prevReplaces) {
                if (prevRop.index >= rop.index && prevRop.lastIndex <= rop.lastIndex) {
                    // delete replace as it's a no-op.
                    rewrites[prevRop.instructionIndex] = undefined;
                    continue;
                }
                // throw exception unless disjoint or identical
                let disjoint =
                    prevRop.lastIndex < rop.index || prevRop.index > rop.lastIndex;
                // Delete special case of replace (text==null):
                // D.i-j.u D.x-y.v	| boundaries overlap	combine to max(min)..max(right)
                if (prevRop.text == null && rop.text == null && !disjoint) {
                    rewrites[prevRop.instructionIndex] = undefined; // kill first delete
                    rop.index = Math.min(prevRop.index, rop.index);
                    rop.lastIndex = Math.max(prevRop.lastIndex, rop.lastIndex);
                }
                else if (!disjoint) {
                    throw new Error(`replace op boundaries of ${rop} overlap with previous ${prevRop}`);
                }
            }
        }

        // WALK INSERTS
        for (let i = 0; i < rewrites.length; i++) {
            let op = rewrites[i];
            if (op == null) {
                continue;
            }
            if (!(op instanceof InsertBeforeOp)) {
                continue;
            }
            let iop = op;
            // combine current insert with prior if any at same index
            let prevInserts = this.getKindOfOps(rewrites, InsertBeforeOp, i);
            for (let prevIop of prevInserts) {
                if (prevIop.index === iop.index) {
                    if (prevIop instanceof InsertAfterOp) {
                        iop.text = this.catOpText(prevIop.text, iop.text);
                        rewrites[prevIop.instructionIndex] = undefined;
                    }
                    else if (prevIop instanceof InsertBeforeOp) { // combine objects
                        // convert to strings...we're in process of toString'ing
                        // whole token buffer so no lazy eval issue with any templates
                        iop.text = this.catOpText(iop.text, prevIop.text);
                        // delete redundant prior insert
                        rewrites[prevIop.instructionIndex] = undefined;
                    }
                }
            }
            // look for replaces where iop.index is in range; error
            let prevReplaces = this.getKindOfOps(rewrites, ReplaceOp, i);
            for (let rop of prevReplaces) {
                if (iop.index === rop.index) {
                    rop.text = this.catOpText(iop.text, rop.text);
                    rewrites[i] = undefined;	// delete current insert
                    continue;
                }
                if (iop.index >= rop.index && iop.index <= rop.lastIndex) {
                    throw new Error(`insert op ${iop} within boundaries of previous ${rop}`);
                }
            }
        }

        let m = new Map();
        for (let op of rewrites) {
            if (op == null) {
                // ignore deleted ops
                continue;
            }
            if (m.get(op.index) != null) {
                throw new Error("should only be one op per index");
            }
            m.set(op.index, op);
        }
        return m;
    }

    catOpText(a, b) {
        let x = "";
        let y = "";
        if (a != null) {
            x = a.toString();
        }
        if (b != null) {
            y = b.toString();
        }
        return x + y;
    }

    /** Get all operations before an index of a particular kind */
    getKindOfOps(rewrites, kind, before) {
        let ops = [];
        for (let i = 0; i < before && i < rewrites.length; i++) {
            let op = rewrites[i];
            if (op == null) {
                // ignore deleted
                continue;
            }
            if (op instanceof kind) {
                ops.push(op);
            }
        }
        return ops;
    }
}

class RewriteOperation {
    constructor(tokens, index, instructionIndex, text) {
        this.tokens = tokens;
        this.instructionIndex = instructionIndex;
        this.index = index;
        this.text = text === undefined ? "" : text;
    }

    execute(buf) {
        return this.index;
    }

    toString() {
        let opName = this.constructor.name;
        const $index = opName.indexOf("$");
        opName = opName.substring($index + 1, opName.length);
        return "<" + opName + "@" + this.tokens.get(this.index) +
            ":\"" + this.text + "\">";
    }
}

class InsertBeforeOp extends RewriteOperation {
    constructor(tokens, index, instructionIndex, text) {
        super(tokens, index, instructionIndex, text);
    }

    execute(buf) {
        buf.push(this.text.toString());
        if (this.tokens.get(this.index).type !== antlr4.Token.EOF) {
            buf.push(String(this.tokens.get(this.index).text));
        }
        return this.index + 1;
    }
}

class InsertAfterOp extends InsertBeforeOp {
    constructor(tokens, index, instructionIndex, text) {
        super(tokens, index + 1, instructionIndex, text); // insert after is insert before index+1
    }
}

class ReplaceOp extends RewriteOperation {
    constructor(tokens, from, to, instructionIndex, text) {
        super(tokens, from, instructionIndex, text);
        this.lastIndex = to;
    }

    execute(buf) {
        if (this.text != null) {
            buf.push(this.text.toString());
        }
        return this.lastIndex + 1;
    }

    toString() {
        if (this.text == null) {
            return "<DeleteOp@" + this.tokens.get(this.index) +
                ".." + this.tokens.get(this.lastIndex) + ">";
        }
        return "<ReplaceOp@" + this.tokens.get(this.index) +
            ".." + this.tokens.get(this.lastIndex) + ":\"" + this.text + "\">";
    }
}
