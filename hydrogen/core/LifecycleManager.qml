import QtQml
import "../logic/Foundation.js" as Foundation

QtObject {
    id: root

    property string state: "starting"
    property string shutdownReason: ""
    property int configurationGeneration: 0
    property bool reloadInProgress: false
    property double startedAtMs: Date.now()
    property var phaseDurations: ({})
    property double phaseStartedAtMs: Date.now()

    signal stateTransitioned(string previousState, string nextState)
    signal shutdownStarted(string reason)
    signal mutationRejected(string operation)

    function transition(nextState) {
        if (!Foundation.canTransition(root.state, nextState))
            return false;
        const previous = root.state;
        const now = Date.now();
        const durations = Object.assign({}, root.phaseDurations);
        durations[previous] = (durations[previous] || 0) + now - root.phaseStartedAtMs;
        root.phaseDurations = durations;
        root.phaseStartedAtMs = now;
        root.state = nextState;
        root.reloadInProgress = nextState === "reloading";
        root.stateTransitioned(previous, nextState);
        return true;
    }

    function mayMutate(operation) {
        const allowed = Foundation.isMutationAllowed(root.state);
        if (!allowed)
            root.mutationRejected(operation);
        return allowed;
    }

    function beginShutdown(reason) {
        if (root.state === "shutting_down" || root.state === "stopped" || root.state === "failed")
            return false;
        root.shutdownReason = reason;
        if (!root.transition("shutting_down"))
            return false;
        root.shutdownStarted(reason);
        return true;
    }
}
