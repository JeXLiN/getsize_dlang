/*
 * Copyright (c) 2020 Sergey Barskov
 * This code is licensed under MIT License (see LICENSE for details)
 */

import std.stdio;
import std.file;
import std.format;
import std.range;
import std.typecons;
import std.math: pow;
import core.stdc.stdlib: exit;
import std.exception: collectException;
import core.exception: RangeError;
import core.sys.posix.sys.stat;
import std.string: toStringz;

const PROGRAM_NAME = "getsize";
const VERSION = "1.0.0";

/**
 * Main class
 */
class GetSize
{
/**
 * Formatted data output
 * Params:
 *   args = List of files
 *   unit = Optional: Bytes, KiB, MiB, GiB, TiB, PiB, EiB, ZiB, YiB
 */
    void getSize(string[] args, string unit="None")
        {
            foreach(file; args){
                foreach(flist; get_file_and_size(file)){
                    if(unit == "None"){
                        writefln("%s %s", convSize(flist[1]), flist[0]);
                    } else{
                        writefln("%s %s", convSize(flist[1], unit), flist[0]);
                    }
                }
            }
        }

/**
 * Get filename and size in bytes
 * Params:
 *   arg = File or directory
 * Returns: List of files
 */
    Tuple!(string, ulong)[] get_file_and_size(string arg)
        {
            Tuple!(string, ulong)[] list_of_files;
            ulong total_dir_size = 0;
            stat_t statbuf;

            try{
                if(arg.isDir){
                    foreach(f; dirEntries(arg, SpanMode.breadth, false)){
                        if(f.isDir)
                            continue;
                        if(f.isSymlink){
                            lstat(f.name.toStringz, &statbuf);
                            list_of_files ~= tuple(f.name, cast(ulong)statbuf.st_size);
                            continue;
                        }
                        total_dir_size += std.file.getSize(f);
                        list_of_files ~= tuple(f.name, std.file.getSize(f));
                    }
                    list_of_files ~= tuple(arg, total_dir_size);

                }else if(arg.isSymlink){
                    lstat(arg.toStringz, &statbuf);
                    list_of_files ~= tuple(arg, cast(ulong)statbuf.st_size);
                }else if(arg.isFile){
                    list_of_files ~= tuple(arg, std.file.getSize(arg));
                }
            }catch(FileException e){
                stderr.writeln(e.msg);
            }

            return list_of_files;
        }

/**
 * Converting bytes to binary prefix
 * Params:
 *   value = Size in bytes
 *   unit = Optional: Bytes, KiB, MiB, GiB, TiB, PiB, EiB, ZiB, YiB
 * Returns: Size and prefix
 *
 * Examples:
 * ---------
 * convSize(4096); // No prefix
 * convSize(4096, "KiB") // With prefix
 * ---------
 */
    string convSize(double value, string unit="None")
        {
            string[] units_values = ["Bytes", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB", "ZiB", "YiB"];

            double[] units_keys = [
                0,
                pow(2, 10.0),
                pow(2, 20.0),
                pow(2, 30.0),
                pow(2, 40.0),
                pow(2, 50.0),
                pow(2, 60.0),
                pow(2, 70.0),
                pow(2, 80.0)];

            auto units = zip(units_values, units_keys);

            string unit_str;

            foreach(k, v; units){
                unit_str = k;
                if(unit == k){
                    if(v < 1024)
                        break;
                    value /= v;
                    break;
                }
                if(unit == "None"){
                    if(value < 1024)
                        break;
                    value /= 1024;
                }
            }

            string output = format("%.3f %s", value, unit_str);
            return output;
        }
}

void usage()
{
    write("Usage: ", PROGRAM_NAME, " [OPTION] [FILE]...\n\n",
          "Options:\n",
          "    -h - Show this help\n",
          "    -v - Show version information\n",
          "    -b - Bytes\n",
          "    -k - KiB\n",
          "    -m - MiB\n",
          "    -g - GiB\n",
          "    -t - TiB\n",
          "    -p - PiB\n",
          "    -e - EiB\n",
          "    -z - ZiB\n",
          "    -y - YiB\n");
}

int main(string[] args)
{
    string[] files;
    RangeError missing_val;
    bool unknown_arg = 0;
    char opt;
    string unit = "None";

    GetSize gs = new GetSize;

    if(args.length == 1){
        files ~= ".";
    } else if(args.length >= 2 && args[1][0] != '-'){
        files ~= args[1..$];
    } else{
        if(args[1][0] == '-'){
            opt = args[1][1];
            missing_val = collectException!RangeError(args[2]);
            if(!missing_val)
                files ~= args[2..$];

            switch(opt){
            case 'h':
                usage();
                exit(0);
                break;
            case 'v':
                writeln(PROGRAM_NAME, " version ", VERSION);
                exit(0);
                break;
            case 'b':
                unit = "Bytes";
                break;
            case 'k':
                unit = "KiB";
                break;
            case 'm':
                unit = "MiB";
                break;
            case 'g':
                unit = "GiB";
                break;
            case 't':
                unit = "TiB";
                break;
            case 'p':
                unit = "PiB";
                break;
            case 'e':
                unit = "EiB";
                break;
            case 'z':
                unit = "ZiB";
                break;
            case 'y':
                unit = "YiB";
                break;
            default:
                unknown_arg = 1;
                break;
            }
        }
    }

    if(unknown_arg){
        stderr.writefln("Unrecognized option: -%c", opt);
        exit(1);
    } else if(missing_val){
        stderr.writefln("Missing value for argument: -%c", opt);
        exit(1);
    } else{
        gs.getSize(files, unit);
    }

    return 0;
}
