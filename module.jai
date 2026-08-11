#import "Basic";
#import "String";
#import "Thread";
#import "Jay_Utils";
#import "Jay_Package";

#load "mixer.jai";
#load "engine.jai";
#load "name.jai";
#load "assets.jai";

using Math :: #import "Jay_Math";
using Logger :: #import "Jay_Logger";

Paths :: struct {
    
    assets_engine ::  #run sprint("%/engine/Jay_Assets", get_working_directory());

    assets_user ::  #run sprint("%/assets", get_working_directory());
    assets_out :: #run sprint("%/bin/assets", get_working_directory());
 
    handlers :: #run sprint("%/handlers", get_working_directory());
}
