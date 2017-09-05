# This file is a part of Julia. License is MIT: https://julialang.org/license

@test ip"127.0.0.1" == IPv4(127,0,0,1)
@test ip"192.0" == IPv4(192,0,0,0)

# These used to work, but are now disallowed. Check that they error
@test_throws ArgumentError parse(IPv4, "192.0xFFF") # IPv4(192,0,15,255)
@test_throws ArgumentError parse(IPv4, "192.0xFFFF") # IPv4(192,0,255,255)
@test_throws ArgumentError parse(IPv4, "192.0xFFFFF") # IPv4(192,15,255,255)
@test_throws ArgumentError parse(IPv4, "192.0xFFFFFF") # IPv4(192,255,255,255)
@test_throws ArgumentError parse(IPv4, "022.0.0.1") # IPv4(18,0,0,1)

@test UInt(IPv4(0x01020304)) == 0x01020304
@test Int(IPv4("1.2.3.4")) == Int(0x01020304) == Int32(0x01020304)
@test Int128(IPv6("2001:1::2")) == 42540488241204005274814694018844196866
@test_throws InexactError Int16(IPv4("1.2.3.4"))
@test_throws InexactError Int64(IPv6("2001:1::2"))

let ipv = parse(IPAddr, "127.0.0.1")
    @test isa(ipv, IPv4)
    @test ipv == ip"127.0.0.1"
end

@test_throws ArgumentError parse(IPv4, "192.0xFFFFFFF")
@test_throws ArgumentError IPv4(192,255,255,-1)
@test_throws ArgumentError IPv4(192,255,255,256)

@test_throws ArgumentError parse(IPv4, "192.0xFFFFFFFFF")
@test_throws ArgumentError parse(IPv4, "192.")

@test ip"::1" == IPv6(1)
@test ip"2605:2700:0:3::4713:93e3" == IPv6(parse(UInt128,"260527000000000300000000471393e3",16))

@test ip"2001:db8:0:0:0:0:2:1" == ip"2001:db8::2:1" == ip"2001:db8::0:2:1"

@test ip"0:0:0:0:0:ffff:127.0.0.1" == IPv6(0xffff7f000001)

let ipv = parse(IPAddr, "0:0:0:0:0:ffff:127.0.0.1")
    @test isa(ipv, IPv6)
    @test ipv == ip"0:0:0:0:0:ffff:127.0.0.1"
end

@test_throws ArgumentError IPv6(1,1,1,1,1,1,1,-1)
@test_throws ArgumentError IPv6(1,1,1,1,1,1,1,typemax(UInt16)+1)

# test InetAddr constructor
let inet = Base.InetAddr(IPv4(127,0,0,1), 1024)
    @test inet.host == ip"127.0.0.1"
    @test inet.port == 1024
end
# test InetAddr invalid port
@test_throws InexactError Base.InetAddr(IPv4(127,0,0,1), -1)
@test_throws InexactError Base.InetAddr(IPv4(127,0,0,1), typemax(UInt16)+1)

# isless and comparisons
@test ip"1.2.3.4" < ip"1.2.3.7" < ip"2.3.4.5"
@test ip"1.2.3.4" >= ip"1.2.3.4" >= ip"1.2.3.1"
@test isless(ip"1.2.3.4", ip"1.2.3.5")
@test_throws MethodError sort[ip"2.3.4.5", ip"1.2.3.4", ip"2001:1:2::1"]

# RFC 5952 Compliance

@test repr(ip"2001:db8:0:0:0:0:2:1") == "ip\"2001:db8::2:1\""
@test repr(ip"2001:0db8::0001") == "ip\"2001:db8::1\""
@test repr(ip"2001:db8::1:1:1:1:1") == "ip\"2001:db8:0:1:1:1:1:1\""
@test repr(ip"2001:db8:0:0:1:0:0:1") == "ip\"2001:db8::1:0:0:1\""
@test repr(ip"2001:0:0:1:0:0:0:1") == "ip\"2001:0:0:1::1\""

# test show() function for UDPSocket()
@test repr(UDPSocket()) == "UDPSocket(init)"

defaultport = rand(2000:4000)
for testport in [0, defaultport]
    port = Channel(1)
    tsk = @async begin
        p, s = listenany(testport)
        put!(port, p)
        sock = accept(s)
        # test write call
        write(sock,"Hello World\n")

        # test "locked" println to a socket
        @sync begin
            for i in 1:100
                @async println(sock, "a", 1)
            end
        end
        close(s)
        close(sock)
    end
    wait(port)
    @test read(connect(fetch(port)), String) == "Hello World\n" * ("a1\n"^100)
    wait(tsk)
end

mktempdir() do tmpdir
    socketname = Sys.iswindows() ? ("\\\\.\\pipe\\uv-test-" * randstring(6)) : joinpath(tmpdir, "socket")
    c = Base.Condition()
    tsk = @async begin
        s = listen(socketname)
        Base.notify(c)
        sock = accept(s)
        write(sock,"Hello World\n")
        close(s)
        close(sock)
    end
    wait(c)
    @test read(connect(socketname), String) == "Hello World\n"
    wait(tsk)
end

# test some unroutable IP addresses (RFC 5737)
@test getnameinfo(ip"192.0.2.1") == "192.0.2.1"
@test getnameinfo(ip"198.51.100.1") == "198.51.100.1"
@test getnameinfo(ip"203.0.113.1") == "203.0.113.1"
@test getnameinfo(ip"0.1.1.1") == "0.1.1.1"
@test getnameinfo(ip"::ffff:0.1.1.1") == "::ffff:0.1.1.1"
@test getnameinfo(ip"::ffff:192.0.2.1") == "::ffff:192.0.2.1"
@test getnameinfo(ip"2001:db8::1") == "2001:db8::1"

# test some valid IP addresses
@test !isempty(getnameinfo(ip"::")::String)
@test !isempty(getnameinfo(ip"0.0.0.0")::String)
@test !isempty(getnameinfo(ip"10.1.0.0")::String)
@test !isempty(getnameinfo(ip"10.1.0.255")::String)
@test !isempty(getnameinfo(ip"10.1.255.1")::String)
@test !isempty(getnameinfo(ip"255.255.255.255")::String)
@test !isempty(getnameinfo(ip"255.255.255.0")::String)
@test !isempty(getnameinfo(ip"192.168.0.1")::String)
@test !isempty(getnameinfo(ip"::1")::String)

let localhost = getnameinfo(ip"127.0.0.1")::String
    @test !isempty(localhost) && localhost != "127.0.0.1"
    @test !isempty(getalladdrinfo(localhost)::Vector{IPAddr})
    @test getaddrinfo(localhost, IPv4)::IPv4 != ip"0.0.0.0"
    @test getaddrinfo(localhost, IPv6)::IPv6 != ip"::"
end
@test_throws Base.DNSError getaddrinfo(".invalid")
@test_throws ArgumentError getaddrinfo("localhost\0") # issue #10994
@test_throws Base.UVError("connect", Base.UV_ECONNREFUSED) connect(ip"127.0.0.1", 21452)

# test invalid port
@test_throws ArgumentError connect(ip"127.0.0.1", -1)
@test_throws ArgumentError connect(ip"127.0.0.1", typemax(UInt16)+1)
@test_throws ArgumentError connect(ip"0:0:0:0:0:ffff:127.0.0.1", -1)
@test_throws ArgumentError connect(ip"0:0:0:0:0:ffff:127.0.0.1", typemax(UInt16)+1)

let (p, server) = listenany(defaultport)
    r = Channel(1)
    tsk = @async begin
        put!(r, :start)
        @test_throws Base.UVError("accept", Base.UV_ECONNABORTED) accept(server)
    end
    @test fetch(r) === :start
    close(server)
    wait(tsk)
end

let (port, server) = listenany(defaultport)
    @async connect("localhost", port)
    s1 = accept(server)
    @test_throws ErrorException accept(server, s1)
    @test_throws Base.UVError listen(port)
    port2, server2 = listenany(port)
    @test port != port2
    close(server)
    close(server2)
end

@test_throws Base.DNSError connect(".invalid",80)

let port = defaultport
    a = UDPSocket()
    b = UDPSocket()
    bind(a, ip"127.0.0.1", port)
    bind(b, ip"127.0.0.1", port + 1)

    c = Condition()
    tsk = @async begin
        @test String(recv(a)) == "Hello World"
        # Issue 6505
        tsk2 = @async begin
            @test String(recv(a)) == "Hello World"
            notify(c)
        end
        send(b, ip"127.0.0.1", port, "Hello World")
        wait(tsk2)
    end
    send(b, ip"127.0.0.1", port, "Hello World")
    wait(c)
    wait(tsk)

    tsk = @async begin
        @test begin
            (addr,data) = recvfrom(a)
            addr == ip"127.0.0.1" && String(data) == "Hello World"
        end
    end
    send(b, ip"127.0.0.1", port, "Hello World")
    wait(tsk)

    @test_throws MethodError bind(UDPSocket(), port)

    close(a)
    close(b)
end

if !Sys.iswindows() || Sys.windows_version() >= Sys.WINDOWS_VISTA_VER
    let port = defaultport
        a = UDPSocket()
        b = UDPSocket()
        bind(a, ip"::1", UInt16(port))
        bind(b, ip"::1", UInt16(port + 1))

        tsk = @async begin
            @test begin
                (addr, data) = recvfrom(a)
                addr == ip"::1" && String(data) == "Hello World"
            end
        end
        send(b, ip"::1", port, "Hello World")
        wait(tsk)
    end
end

for (addr, porthint) in [(IPv4("127.0.0.1"), UInt16(11011)),
                    (IPv6("::1"), UInt16(11012)), (getipaddr(), UInt16(11013))]
    port, listen_sock = listenany(addr, porthint)
    gsn_addr, gsn_port = getsockname(listen_sock)

    @test addr == gsn_addr
    @test port == gsn_port

    @test_throws MethodError getpeername(listen_sock)

    # connect to it
    client_sock = connect(addr, port)
    server_sock = accept(listen_sock)

    self_client_addr, self_client_port = getsockname(client_sock)
    peer_client_addr, peer_client_port = getpeername(client_sock)
    self_srvr_addr, self_srvr_port = getsockname(server_sock)
    peer_srvr_addr, peer_srvr_port = getpeername(server_sock)

    @test self_client_addr == peer_client_addr == self_srvr_addr == peer_srvr_addr

    @test peer_client_port == self_srvr_port
    @test peer_srvr_port == self_client_port
    @test self_srvr_port != self_client_port

    close(listen_sock)
    close(client_sock)
    close(server_sock)
end

# Local-machine broadcast
let
    # (Mac OS X's loopback interface doesn't support broadcasts)
    bcastdst = Sys.isapple() ? ip"255.255.255.255" : ip"127.255.255.255"

    function create_socket()
        s = UDPSocket()
        bind(s, ip"0.0.0.0", 2000, reuseaddr = true, enable_broadcast = true)
        s
    end

    function wait_with_timeout(recvs)
        TIMEOUT_VAL = 3  # seconds
        t0 = time()
        recvs_check = copy(recvs)
        while ((length(filter!(t->!istaskdone(t), recvs_check)) > 0)
              && (time() - t0 < TIMEOUT_VAL))
            sleep(0.05)
        end
        length(recvs_check) > 0 && error("timeout")
        map(wait, recvs)
    end

    a, b, c = [create_socket() for i = 1:3]
    try
        # bsd family do not allow broadcasting to ip"255.255.255.255"
        # or ip"127.255.255.255"
        @static if !Sys.isbsd() || Sys.isapple()
            send(c, bcastdst, 2000, "hello")
            recvs = [@async @test String(recv(s)) == "hello" for s in (a, b)]
            wait_with_timeout(recvs)
        end
    catch e
        if isa(e, Base.UVError) && Base.uverrorname(e) == "EPERM"
            warn("UDP broadcast test skipped (permission denied upon send, restrictive firewall?)")
        else
            rethrow()
        end
    end
    [close(s) for s in [a, b, c]]
end

let P = Pipe()
    Base.link_pipe(P)
    write(P, "hello")
    @test nb_available(P) == 0
    @test !eof(P)
    @test read(P, Char) === 'h'
    @test !eof(P)
    @test read(P, Char) === 'e'
    @test isopen(P)
    t = @async begin
        # feed uv_read one more event so that it triggers the transition from active -> open
        write(P, "w")
        while P.out.status != Base.StatusOpen
            yield() # wait for that transition
        end
        close(P.in)
    end
    # on unix, this proves that the kernel can buffer a single byte
    # even with no registered active call to read
    # on windows, the kernel fails to do even that
    # causing the `write` call to freeze
    # so we end up forced to do a slightly weaker test here
    Sys.iswindows() || wait(t)
    @test isopen(P) # without an active uv_reader, P shouldn't be closed yet
    @test !eof(P) # should already know this,
    @test isopen(P) #  so it still shouldn't have an active uv_reader
    @test readuntil(P, 'w') == "llow"
    Sys.iswindows() && wait(t)
    @test eof(P)
    @test !isopen(P) # eof test should have closed this by now
    close(P) # should be a no-op, just make sure
    @test !isopen(P)
    @test eof(P)
end

# test the method matching connect!(::TCPSocket, ::Base.InetAddr{T<:Base.IPAddr})
let
    addr = Base.InetAddr(ip"127.0.0.1", 4444)

    function test_connect(addr::Base.InetAddr)
        srv = listen(addr)

        @async try c = accept(srv); close(c) catch end
        yield()

        t0 = TCPSocket()
        t = t0
        @assert t === t0

        try
            t = connect(addr)
        finally
            close(srv)
        end

        test = t !== t0
        close(t)

        return test
    end

    @test test_connect(addr)
end

