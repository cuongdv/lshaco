var pollingInterval;
    _ws = new WebSocket("ws://192.168.0.4:1234/test.js");
    _ws.onopen = function () {
        document.getElementById('txt1').value = "open"
        console.log("onopen")
        _socketCreated = true;
        var args
        _ws.send(Array(20).join("1234567890"));
        _ws.send("33322233");
    };
    _ws.onmessage = function (event) {
        console.log("event.data=" + event.data);
        document.getElementById('txt1').value = event.data
                    
    };
    _ws.onclose = function (ev) {
        document.write("<p>"+"close"+ev.code+ev.reason+"</p>")
        console.log("onclose="+ev.code+ev.reason);
    };
    _ws.onerror = function (ev) {
        document.write("<p>"+"error"+ev.code+ev.reason+"</p>")
        document.getElementById('txt1').value = "error"+ev.code+ev.reason
        console.log("onerror="+ev.code+ev.reason);
    };
    function send() {
        _ws.send(document.getElementById("msg").value);
    }
