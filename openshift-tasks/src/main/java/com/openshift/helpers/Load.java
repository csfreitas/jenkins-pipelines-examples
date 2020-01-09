package com.openshift.helpers;

import java.util.logging.Level;
import java.util.logging.Logger;

public class Load {
    public void generateLoad(long duration) {
        int numCore = 2;
        int numThreadsPerCore = 2;
        double load = 0.8;
        for (int thread = 0; thread < numCore * numThreadsPerCore; thread++) {
            new BusyThread("Thread" + thread, load, duration).start();
        }
    }

    private class BusyThread extends Thread {
        private double load;
        private long duration;

        public BusyThread(String name, double load, long duration) {
            super(name);
            this.load = load;
            this.duration = duration;
        }

        
        @Override
        public void run() {
            long startTime = System.currentTimeMillis();
            Logger log = Logger.getLogger(Load.class.getName());
            try {
                log.log(Level.INFO, "INFO: Starting loop fot the given duration: " + seconds + " seconds.");
                // Loop for the given duration
                while (System.currentTimeMillis() - startTime < duration) {
                    if (System.currentTimeMillis() % 100 == 0) {
                        Thread.sleep((long) Math.floor((1 - load) * 100));
                    }
                }
                log.log(Level.INFO, "INFO: Ending loop after: " + seconds + " seconds.");
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }
    }
}