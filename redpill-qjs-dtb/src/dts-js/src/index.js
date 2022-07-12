import antlr4 from 'antlr4';
import DTSLexer from './DTSLexer.js';
import DTSParser from './DTSParser.js';
import MyDTSListener from "./MyDTSListener.js";
// import os from "os";
// import std from "std";

if (!String.format) {
    String.format = function (format) {
        let args = Array.prototype.slice.call(arguments, 1);
        return format.replace(/{(\d+)}/g, function (match, number) {
            return typeof args[number] != 'undefined'
                ? args[number]
                : match
                ;
        });
    };
}

const args = scriptArgs;
if (args.length < 2 || args.length > 3) {
    std.out.printf('Usage: qjs dts.js <path to dts file> [output path]\n');
    std.exit(1);
}
let filePath = args[1];

let outFilePath = args.length > 2 ? args[2] : filePath + ".out";
const input = std.loadFile(filePath);

const chars = new antlr4.InputStream(input);
const lexer = new DTSLexer(chars);
const tokens = new antlr4.CommonTokenStream(lexer);
const parser = new DTSParser(tokens);
parser.buildParseTrees = true;
const tree = parser.dts();

const walker = new antlr4.tree.ParseTreeWalker();
const sta = new MyDTSListener(tokens);
walker.walk(sta, tree);

const block_path = "/sys/block/";
let data = os.readdir(block_path);

if (data[1] === 0) {
    // success
    let prefix = "/sys/block/sata";
    let regex = /\/sys\/block\/nvme(\d{1,2})n(\d{1,2})/i;
    for (let dataKey in data[0]) {
        let path = block_path + data[0][dataKey];
        try {
            std.out.printf("start processing path:%s\n", path);
            if (path.toString().startsWith(prefix)) {
                let num = Number.parseInt(path.toString().substring(prefix.length));
                let map = readPropertiesFile(path + "/device/syno_block_info");
                //pciepath=00:12.0
                //ata_port_no=0
                //driver=ahci
                if (map.get("driver") === "ahci") {
                    sta.put(String.format("/internal_slot@{0}/ahci/pcie_root", num), String.format("\"{0}\"", map.get("pciepath")));
                    sta.put(String.format("/internal_slot@{0}/ahci/ata_port", num), String.format("<0x{0}>", Number.parseInt(map.get("ata_port_no")).toString(16).padStart(2, "0")));
                } else {
                    std.out.printf("not ahci\n");
                }
            } else if (path.toString().startsWith("/sys/block/nvme")) {
                let matches;
                if ((matches = regex.exec(path.toString()))) {
                    let num = Number.parseInt(matches[1]);
                    let map = readPropertiesFile(path + "/device/syno_block_info");
                    //pciepath=00:12.0
                    sta.put(String.format("/nvme_slot@{0}/pcie_root", num + 1), String.format("\"{0}\"", map.get("pciepath")));
                } else {
                    std.out.printf("nvme not found\n");
                }
            } else {
                std.out.printf("unsupported\n");
            }
        } catch (err) {
            std.out.printf("update path: %s to dts error: %s\n", path, err.message);
            std.exit(1);
        }
    }
    const open = std.open(outFilePath, "w");
    open.puts(sta.rewriter.getText());
    open.close();
} else {
    // error
    std.out.printf("update dts error:%d\n", data[1]);
    std.exit(1);
}

function readPropertiesFile(path) {
    const open = std.open(path, "r");
    let map = new Map();
    while (true) {
        let line = open.getline();
        if (line === null) {
            break;
        }
        let index = line.indexOf("=");
        if (index > 0) {
            let k = line.substring(0, index);
            let v = line.substring(index + 1);
            map.set(k, v);
            std.out.printf("%s = %s\n", k, v);
        }
    }
    open.close();
    return map;
}
