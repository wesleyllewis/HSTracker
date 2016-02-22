//
//  AppDelegate.swift
//  HSTracker
//
//  Created by Benjamin Michotte on 19/02/16.
//  Copyright © 2016 Benjamin Michotte. All rights reserved.
//

import Cocoa
import CocoaLumberjack
import MagicalRecord

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var splashscreen: Splashscreen?
    var playerTracker: Tracker?
    var opponentTracker: Tracker?
    var language: Language?

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        if let _ = NSUserDefaults.standardUserDefaults().objectForKey("hstracker_v2") {
            // welcome to HSTracker v2
        } else {
            for (key,_) in NSUserDefaults.standardUserDefaults().dictionaryRepresentation() {
                NSUserDefaults.standardUserDefaults().removeObjectForKey(key)
            }
            NSUserDefaults.standardUserDefaults().synchronize()
            NSUserDefaults.standardUserDefaults().setBool(true, forKey: "hstracker_v2")
        }
        
        // init core data stuff
        MagicalRecord.setupAutoMigratingCoreDataStack()

        // init logger
#if DEBUG
        DDTTYLogger.sharedInstance().colorsEnabled = true
        DDLog.addLogger(DDTTYLogger.sharedInstance())
#else
        var fileLogger: DDFileLogger = DDFileLogger()
        fileLogger.rollingFrequency = 60 * 60 * 24
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7
        DDLog.addLogger(fileLogger)
#endif

        // check for player locale
        language = Language()
        DDLogDebug("Is user language set ? : \(language!.isLanguageSet() ? "yes" : "no")")
        if language!.isLanguageSet() {
            loadSplashscreen()
        } else {
            language!.presentLanguageChooserWithCompletion() {
                self.loadSplashscreen()
            }
        }
    }

    func loadSplashscreen() {
        splashscreen = Splashscreen(windowNibName: "Splashscreen")
        splashscreen!.showWindow(self)
        let operationQueue = NSOperationQueue()

        let startUpCompletionOperation = NSBlockOperation(block: {
            NSOperationQueue.mainQueue().addOperationWithBlock() {
                self.hstrackerReady()
            }
        })

        let databaseOperation = NSBlockOperation(block: {
            let database = Database()
            if let images = database.loadDatabaseIfNeeded(self.splashscreen!) {
                DDLogVerbose("need to download \(images)")
                let imageDownloader = ImageDownloader()
                imageDownloader.downloadImagesIfNeeded(images, splashscreen: self.splashscreen!)
            }
        })
        let loggingOperation = NSBlockOperation(block: {
            DDLogInfo("Starting logging")
            Hearthstone.instance.start()
            Game.instance.setPlayerTracker(self.playerTracker)
            Game.instance.setOpponentTracker(self.opponentTracker)
        })
        let trackerOperation = NSBlockOperation(block: {
            NSOperationQueue.mainQueue().addOperationWithBlock() {
                DDLogInfo("Opening trackers")
                self.openTrackers()
            }
        })

        startUpCompletionOperation.addDependency(loggingOperation)
        loggingOperation.addDependency(trackerOperation)
        trackerOperation.addDependency(databaseOperation)
        operationQueue.addOperation(startUpCompletionOperation)
        operationQueue.addOperation(databaseOperation)
        operationQueue.addOperation(trackerOperation)
        operationQueue.addOperation(loggingOperation)
    }

    func hstrackerReady() {
        DDLogInfo("HSTracker is now ready !")
        if let splashscreen = splashscreen {
            splashscreen.close()
            self.splashscreen = nil
        }
    }

    func openTrackers() {
        self.playerTracker = Tracker(windowNibName: "Tracker")
        if let tracker = self.playerTracker {
            tracker.playerType = .Player
            tracker.showWindow(self)
        }

        self.opponentTracker = Tracker(windowNibName: "Tracker")
        if let tracker = self.opponentTracker {
            tracker.playerType = .Opponent
            tracker.showWindow(self)
        }
    }

    func applicationWillTerminate(aNotification: NSNotification) {

    }

}

