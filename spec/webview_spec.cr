require "./spec_helper"

describe Webview do
  it "has a version number" do
    Webview::VERSION.should be_a(String)
  end
end

{% if flag?(:darwin) %}
  # Regression guard for macOS 26+ (Tahoe) crashes in cocoa_wkwebview_engine
  # when the destructor is invoked from a non-OS-main thread.
  #
  # Root cause: Crystal's preview_mt execution model parks Thread 0 (the OS
  # main thread, where [NSThread isMainThread] returns true) in a condition
  # variable and runs __crystal_main — including NSApp.run — on a worker
  # thread. When the user closes the window, NSApp terminates, run() returns,
  # and destroy() is called from that same worker thread.
  #
  # In this post-run state the window is already closed by NSApp (contentView
  # has been cleared), so the early window-cleanup block in the destructor is
  # a no-op. Control falls through to deplete_run_loop_event_queue(), which
  # calls [NSApp nextEventMatchingMask:]. On macOS 26+ that method enforces
  # [NSThread isMainThread] strictly: calling it from a non-main thread raises
  # an ObjC exception that propagates as std::terminate → SIGABRT.
  #
  # Fix: guard deplete_run_loop_event_queue with an isMainThread check and
  # return early when off-main. The drain is cosmetic at that point — the
  # window is already gone.
  #
  # Note: the test below cannot fully reproduce the crash in a spec environment
  # because calling destroy() before run() leaves the window's contentView
  # intact, triggering a *different* off-main AppKit violation in WebKit's
  # WKWindowVisibilityObserver. The real crash occurs specifically in the
  # post-run state where NSApp has already closed the window. The fix is
  # verified by running an actual Lune app under preview_mt on macOS 26+.
  describe "macOS 26+ destroy safety" do
    it "Webview#destroy is defined and callable (compile check)" do
      # Verify the method exists. Full runtime validation of the off-main
      # destructor path requires a live NSApp event loop (see comment above).
      typeof(Webview::Webview.allocate.destroy)
    end

    pending "destroy called from non-main Thread after NSApp lifecycle does not crash" do
      # To reproduce: create a webview, call run (NSApp event loop starts),
      # close the window (terminate called), then call destroy from the worker
      # thread that ran the loop. Without the isMainThread guard, this aborts
      # via std::terminate. Cannot be automated in crystal spec because run()
      # blocks and requires an interactive display session.
    end
  end
{% end %}
