
OS = $(shell uname)
ifeq ($(OS), MINGW32_NT-6.1)
OS=WINNT
endif

LIBS = -luv 
ifeq ($(OS), Linux)
LIBS += -lpthread -lrt 
endif

EXE=
ifeq ($(OS),WINNT)
LIBS += -lws2_32 -liphlpapi -lpsapi
EXE=.exe
endif

ifeq ($(OS),Darwin)
LIBS += -framework ApplicationServices
endif

WEBSERVER_SRCS = webserver.o server.o jsoncpp.o
WEBSERVER_DSRCS = webserver.do server.do jsoncpp.do

%.o: %.cpp *.h
	$(QUIET_CC)$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@
%.do: %.cpp *.h
	$(QUIET_CC)$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@

julia-release julia-debug: %: %-webserver$(EXE)

release debug:
	$(MAKE) julia-$@

julia-release-webserver$(EXE): $(WEBSERVER_SRCS)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -o $@ $(LDFLAGS) $(WEBSERVER_SRCS) $(LIBS)

julia-debug-webserver$(EXE): $(WEBSERVER_DSRCS)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -o $@ $(LDFLAGS) $(WEBSERVER_DSRCS) $(LIBS)

../../src/webrepl_msgtypes_h.jl: message_types.h
	$(CC) -E $(CPPFLAGS) -Djl_output $< > $@
jl_message_types: ../../src/webrepl_msgtypes_h.jl

clean:
	rm -f *.o *.do julia-*-webserver ../../src/webrepl_msgtypes_h.jl
