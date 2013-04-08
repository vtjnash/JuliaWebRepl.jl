using BinDeps

msize = sizeof(Int)==4 ? "-m32" : "-m64"
VER="0.0.0$msize"
NGINX_VER="1.2.7"
this_julia = JULIA_HOME #Note: this will get hardcoded into the launch script

s = @build_steps begin
    c=Choices(Choice[
        Choice(:skip,"Skip Installation - Nginx must be installed manually",nothing),])
end

## Prebuilt Binaries
depsdir = joinpath(Pkg.dir(),"JuliaWebRepl","deps")
prefix=joinpath(depsdir,"usr")
sysimgdir = ccall(:jl_locate_sysimg, Ptr{Uint8}, (Ptr{Uint8},), this_julia)
JL_PRIVATE_LIBDIR = dirname(bytestring(sysimgdir))
JL_LIBDIR = "lib"
Base.c_free(sysimgdir)
JL_PRIVATE_LIBDIR = abspath(JL_PRIVATE_LIBDIR)

exe = OS_NAME==:Windows ? ".exe" : ""
if OS_NAME == :Windows
    ## Install from binaries
    local_file = joinpath(joinpath(depsdir,"downloads"),"nginx-$NGINX_VER.zip")
    push!(c,Choice(:binary,"Download nginx",
        @build_steps begin
            ChangeDirectory(depsdir)
            FileDownloader("http://nginx.org/download/nginx-$NGINX_VER.zip",local_file)
            FileUnpacker(local_file,joinpath(depsdir,"usr/nginx-$NGINX_VER"))
            CreateDirectory(joinpath(prefix,"sbin"))
            `cp -a usr/nginx-$NGINX_VER/nginx$exe usr/sbin/nginx$exe`
            `cp -a usr/nginx-$NGINX_VER/* usr/`
        end))
else
    ## Install from source
    steps  = @build_steps begin ChangeDirectory(depsdir) end
    #libdir=joinpath(prefix,"lib")
    #steps |= @build_steps begin CreateDirectory(libdir) end
    #steps |= @build_steps function()
    #    println("Copying libpcre from julia installation")
    #    if isdir("$this_julia/../lib")
    #        for f in readdir("$this_julia/../lib")
    #            if begins_with(f, "libpcre")
    #                cp(joinpath(this_julia,"..","lib",f),libdir)
    #            end
    #        end
    #    end
    #    if isdir("$JL_PRIVATE_LIBDIR")
    #        for f in readdir("$JL_PRIVATE_LIBDIR")
    #            if begins_with(f, "libpcre")
    #                cp(joinpath(JL_PRIVATE_LIBDIR,f),libdir)
    #            end
    #        end
    #    end
    #    nothing
    #end

    directory = "nginx-$NGINX_VER"
    steps |= @build_steps begin
        prepare_src(depsdir, "http://nginx.org/download/nginx-$NGINX_VER.tar.gz", "nginx-$NGINX_VER.tar.gz", directory)
        function()
            println("Patching nginx")
            f = open("src/$directory/configure","a")
            write(f,"\necho export DESTDIR=$(prefix)/ >> Makefile\n")
            write(f,"\n. auto/summary > config.status\n")
            close(f)
        end
    end
        steps |= @build_steps begin
                BinDeps.AutotoolsDependency(
            joinpath(depsdir,"src",directory), #srcdir
            ".", #prefix
            joinpath(depsdir,"src",directory), #builddir
            String[
                "--without-http_gzip_module",
                "--without-http_rewrite_module",
                #"--with-ld-opt=-L$(libdir) -lpcre",
                "--with-debug"], #configureopts
            "objs/nginx", #library name
            "$prefix/sbin/nginx", #install name
            "") #config.status directory
            end
        push!(c,Choice(:source,"Install Nginx dependency from source",steps))
end

filename = "launch-julia-webserver"
if OS_NAME == :Windows
    filename = "$filename.bat"
end
s |= @build_steps begin
    ChangeDirectory(depsdir)
    CreateDirectory(joinpath(prefix,"etc"))
    CreateDirectory(joinpath(prefix,"bin"))
    FileRule(joinpath("usr","etc","nginx.conf"),`cp $(joinpath(depsdir,"src/nginx.conf")) $(joinpath(prefix,"etc"))`)
    function()
        fin = fout = nothing
        try
            fin = open(joinpath("src",filename))
            fout = open(joinpath("usr","bin",filename),"w")
            write(fout, readline(fin))
            if OS_NAME == :Windows
                write(fout, "set JULIA_HOME=$this_julia\r\n")
                write(fout, "set THIS_SCRIPT=$(joinpath(prefix,"bin"))\\\r\n")
            else
                write(fout, "export JULIA_HOME=$this_julia\n")
                write(fout, "export THIS_SCRIPT=$(joinpath(prefix,"bin"))\n")
            end
            write(fout, readall(fin))
        finally
            if !(fin===nothing) close(fin) end
            if !(fout===nothing) close(fout) end
        end
        @unix_only readall(`chmod a+x $(joinpath("usr","bin",filename))`)
    end
end

steps  = @build_steps begin
    ChangeDirectory(depsdir)
    BinDeps.MakeTargets(ASCIIString[
        "-Csrc", "julia-release", OS_NAME==:Windows?"OS=WINNT":"IGNOREME=1",
        """CPPFLAGS=-I$(joinpath(this_julia,"..","include","julia")) \\
                -I$(joinpath(this_julia,"..","include")) \\
                -I$(joinpath(this_julia,"..","..","src")) \\
                $msize""",
        """LDFLAGS=-L$(joinpath(this_julia,"..","lib")) \\
                -L$(JL_PRIVATE_LIBDIR) $msize"""])
        `cp src/julia-release-webserver$exe usr/bin`
    #FileRule("usr/bin/julia-release-webserver$exe",
    #   `cp src/julia-release-webserver$exe usr/bin`)
    BinDeps.MakeTargets(ASCIIString[
        "-Csrc", "jl_message_types", OS_NAME==:Windows?"OS=WINNT":"IGNOREME=1",
        "CPPFLAGS=-I$(joinpath(this_julia,"..","include","julia")) -I$(joinpath(this_julia,"..","include")) -I$(joinpath(this_julia,"..","..","src")) $msize",
        "LDFLAGS=-L$(joinpath(this_julia,"..","lib")) -L$(JL_PRIVATE_LIBDIR) $msize"])
    `cp usr/bin/webrepl_msgtypes_h.jl ../src/`
end

if OS_NAME == :Windows
    s |= @build_steps begin
        c=Choices(Choice[Choice(:source,"Install Julia-Webserver dependency from source",steps),])
    end
    local_file = joinpath(joinpath(depsdir,"downloads"),"julia_webserver-$VER.zip")
    destf = joinpath(prefix,"bin","julia-release-webserver$exe")
    push!(c,Choice(:binary,"Download julia_webserver binaries",
        @build_steps begin
            ChangeDirectory(depsdir)
            FileDownloader("http://julialang.googlecode.com/files/julia_webserver-$VER.zip",local_file)
            FileRule(destf,unpack_cmd(local_file,dirname(destf)))
            `cp usr/bin/webrepl_msgtypes_h.jl ../src/`
        end))
    homedir = ENV["USERPROFILE"]
else
    s |= steps
    homedir = ENV["HOME"]
end

s |= @build_steps begin
    c=Choices(Choice[
        Choice(:skip,"Skip link creation -- launch from ~/.julia/deps/usr/bin/launch-julia-webserver",nothing),
        Choice(:home,"Create symbolic link in home directory -- launch from ~/launch-julia-webserver",
            @build_steps begin
               `ln -fs $(joinpath(prefix,"bin",filename)) $(joinpath(homedir,filename))`
            end),
        Choice(:desktop,"Create symbolic link on Desktop -- launch from ~/Desktop/launch-julia-webserver",
            @build_steps begin
               `ln -fs $(joinpath(prefix,"bin",filename)) $(joinpath(homedir,"Desktop",filename))`
            end),
        Choice(:julia,"Create symbolic link in JULIA_HOME directory -- launch from $(JULIA_HOME)/launch-julia-webserver",
            @build_steps begin
               `ln -fs $(joinpath(prefix,"bin",filename)) $(joinpath(JULIA_HOME,filename))`
            end),
        ])
end

run(s)
