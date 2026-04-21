@import "Chumpinate"

Package pkg("chudel");
pkg.authors(["Brendan Zelikman"]);
pkg.homepage("https://ccrma.stanford.edu/~brendan/chudel");
pkg.description("A ChucKian port of Strudel.");
pkg.license("MIT");
pkg.keywords(["live-code", "live code", "strudel", "tidal cycles"]);
pkg.generatePackageDefinition("./");
pkg.repository("");

PackageVersion ver("chudel", "0.1.0");
ver.languageVersionMin("1.5.4.5");
ver.os("any");
ver.arch("all");
ver.addFile("src/bass.wav", "src");
ver.addFile("src/bd.wav", "src");
ver.addFile("src/cp.wav", "src");
ver.addFile("src/hh.wav", "src");
ver.addFile("src/oh.wav", "src");
ver.addFile("src/piano.wav", "src");
ver.addFile("src/sd.wav", "src");
ver.addFile("src/chudel.ck", "src");
ver.addFile("chudel.ck");
ver.addFile("src/hap.ck", "src");
ver.addFile("src/parser.ck", "src");
ver.addFile("src/pattern.ck", "src");
ver.addFile("src/recorder.ck", "src");
ver.addFile("src/sampler.ck", "src");
ver.addFile("src/scale.ck", "src");
ver.addFile("src/utils.ck", "src");
ver.addFile("src/examples.ck", "src");

ver.generateVersion("./", "chudel", "https://ccrma.stanford.edu/~brendan/chudel/chudel.zip");
ver.generateVersionDefinition("chudel", "./");