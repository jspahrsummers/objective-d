import std.c.stdlib;
import std.file;
import std.getopt;
import std.stdio;
import preprocessor;

immutable string defaultOutputFilename = "main.d";

int main (string[] args) {
    string outputFile = null;
    string[] includePaths;
    string[] inputFiles;
    
    getopt(args,
        std.getopt.config.bundling,
        "of|o", &outputFile,
        "I", &includePaths
    );
    
    assert(args.length > 0, "no invocation argument passed");
    inputFiles = args[1 .. $];
    
    if (outputFile is null) {
        outputFile = defaultOutputFilename;
        if (exists(outputFile)) {
            stderr.writefln("Default output file \"%s\" already exists. You must pass the -o flag to overwrite its contents.", defaultOutputFilename);
            return EXIT_FAILURE;
        }
    } else if (outputFile == "") {
        stderr.writefln("Invalid output filename. Leave blank to use the default.");
        return EXIT_FAILURE;
    }
    
    if (inputFiles is null || inputFiles.length == 0) {
        stderr.writefln("No input files provided.");
        return EXIT_FAILURE;
    }
    
    if (Parser.preprocess(inputFiles, outputFile, includePaths))
        return EXIT_SUCCESS;
    else
        return EXIT_FAILURE;
}
