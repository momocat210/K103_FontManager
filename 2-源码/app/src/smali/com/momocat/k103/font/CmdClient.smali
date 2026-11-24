.class public Lcom/momocat/k103/font/CmdClient;
.super Landroid/webkit/WebViewClient;
.source "SourceFile"


# instance fields
.field final act:Lcom/momocat/k103/font/MainActivity;


# direct methods
.method public constructor <init>(Lcom/momocat/k103/font/MainActivity;)V
    .locals 0

    invoke-direct {p0}, Landroid/webkit/WebViewClient;-><init>()V

    iput-object p1, p0, Lcom/momocat/k103/font/CmdClient;->act:Lcom/momocat/k103/font/MainActivity;

    return-void
.end method

.method private handle(Landroid/webkit/WebView;Ljava/lang/String;)Z
    .locals 4

    const/4 v0, 0x0

    if-nez p2, :cond_0

    return v0

    :cond_0
    const-string v1, "http://cmd.local/run/"

    invoke-virtual {p2, v1}, Ljava/lang/String;->startsWith(Ljava/lang/String;)Z

    move-result v2

    if-nez v2, :cond_1

    return v0

    :cond_1
    invoke-virtual {v1}, Ljava/lang/String;->length()I

    move-result v1

    invoke-virtual {p2, v1}, Ljava/lang/String;->substring(I)Ljava/lang/String;

    move-result-object v1

    iget-object v2, p0, Lcom/momocat/k103/font/CmdClient;->act:Lcom/momocat/k103/font/MainActivity;

    new-instance v3, Lcom/momocat/k103/font/CmdTask;

    invoke-direct {v3, v2, p1, v1}, Lcom/momocat/k103/font/CmdTask;-><init>(Lcom/momocat/k103/font/MainActivity;Landroid/webkit/WebView;Ljava/lang/String;)V

    new-instance v2, Ljava/lang/Thread;

    invoke-direct {v2, v3}, Ljava/lang/Thread;-><init>(Ljava/lang/Runnable;)V

    invoke-virtual {v2}, Ljava/lang/Thread;->start()V

    const/4 v0, 0x1

    return v0
.end method


# virtual methods
.method public shouldOverrideUrlLoading(Landroid/webkit/WebView;Landroid/webkit/WebResourceRequest;)Z
    .locals 3

    invoke-interface {p2}, Landroid/webkit/WebResourceRequest;->getUrl()Landroid/net/Uri;

    move-result-object v0

    invoke-virtual {v0}, Landroid/net/Uri;->toString()Ljava/lang/String;

    move-result-object v0

    invoke-direct {p0, p1, v0}, Lcom/momocat/k103/font/CmdClient;->handle(Landroid/webkit/WebView;Ljava/lang/String;)Z

    move-result v1

    return v1
.end method

.method public shouldOverrideUrlLoading(Landroid/webkit/WebView;Ljava/lang/String;)Z
    .locals 1

    invoke-direct {p0, p1, p2}, Lcom/momocat/k103/font/CmdClient;->handle(Landroid/webkit/WebView;Ljava/lang/String;)Z

    move-result v0

    return v0
.end method
