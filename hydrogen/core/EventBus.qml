import QtQml

QtObject {
    signal phaseStarted(string phase)
    signal phaseFinished(string phase)
    signal configurationAccepted(int previousGeneration, int currentGeneration)
    signal configurationRejected(string code)
    signal shutdownStarted(string reason)
    signal shutdownFinished(string reason)
}
