# Automatically generated from the noweb directory
plot.survfit<- function(x, conf.int,  mark.time=FALSE,
                        pch=3,  col=1,lty=1, lwd=1, 
                        cex=1, log=FALSE,
                        xscale=1, yscale=1, 
                        xlim, ylim, xmax, 
                        fun, xlab="", ylab="", xaxs='r', 
                        conf.times, conf.cap=.005, conf.offset=.012, 
                        conf.type=c('log',  'log-log',  'plain', 
                                  'logit', "arcsin"),
                        mark, noplot="(s0)", cumhaz=FALSE,
                        firstx, ymin, ...) {

    dotnames <- names(list(...))
    if (any(dotnames =='type'))
        stop("The graphical argument 'type' is not allowed")
    x <- survfit0(x, x$start.time)   # align data at 0 for plotting

    # decide on logarithmic axes, yes or no
    if (is.logical(log)) {
        ylog <- log
        xlog <- FALSE
        if (ylog) logax <- 'y'
        else      logax <- ""
    }
    else {
        ylog <- (log=='y' || log=='xy')
        xlog <- (log=='x' || log=='xy')
        logax  <- log
    }

    if (!missing(fun)) {
        if (is.character(fun)) {
            if (fun=='log'|| fun=='logpct') ylog <- TRUE
            if (fun=='cloglog') {
                xlog <- TRUE
                if (ylog) logax <- 'xy'
                else logax <- 'x'
            }
        }
    }
    # The default for plot and lines is to add confidence limits
    #  if there is only one curve
    if (missing(conf.int) && missing(conf.times))  
        conf.int <- (!is.null(x$std.err) && prod(dim(x) ==1))

    if (missing(conf.times)) conf.times <- NULL   
    else {
        if (!is.numeric(conf.times)) stop('conf.times must be numeric')
        if (missing(conf.int)) conf.int <- TRUE
    }

    if (!missing(conf.int)) {
        if (is.numeric(conf.int)) {
            conf.level <- conf.int
            if (conf.level<0 || conf.level > 1)
                stop("invalid value for conf.int")
            if (conf.level ==0) conf.int <- FALSE
            else if (conf.level != x$conf.int) {
                x$upper <- x$lower <- NULL  # force recomputation
            }
            conf.int <- TRUE
        }
        else conf.level = 0.95
    }

    # Organize data into stime, ssurv, supper, slower
    stime <- x$time
    std   <- NULL
    yzero <- FALSE   # a marker that we have an "ordinary survival curve" with min 0
    smat <- function(x) {
        # the rest of the routine is simpler if everything is a matrix
        dd <- dim(x)
        if (is.null(dd)) as.matrix(x)
        else if (length(dd) ==2) x
        else matrix(x, nrow=dd[1])
    }

    if (cumhaz) {  # plot the cumulative hazard instead
        if (is.null(x$cumhaz)) 
            stop("survfit object does not contain a cumulative hazard")

        if (is.numeric(cumhaz)) {
            dd <- dim(x$cumhaz)
            if (is.null(dd)) nhazard <- 1
            else nhazard <- prod(dd[-1])

            if (cumhaz != floor(cumhaz)) stop("cumhaz argument is not integer")
            if (any(cumhaz < 1 | cumhaz > nhazard)) stop("subscript out of range")
            ssurv <- smat(x$cumhaz)[,cumhaz, drop=FALSE]
            if (!is.null(x$std.chaz)) std <- smat(x$std.chaz)[,cumhaz, drop=FALSE]
        }
        else if (is.logical(cumhaz)) {
            ssurv <- smat(x$cumhaz)
            if (!is.null(x$std.chaz)) std <- smat(x$std.chaz)
        }
        else stop("invalid cumhaz argument")
    }
    else if (inherits(x, "survfitms")) {
        i <- (x$states != noplot)
        if (all(i) || !any(i)) {
            # the !any is a failsafe, in case none are kept then ignore noplot
            ssurv <- smat(x$pstate)
            if (!is.null(x$std.err)) std <- smat(x$std.err)
        }
        else {
            i <- which(i)  # the states to keep
            # we have to be careful about subscripting
            if (length(dim(x$pstate)) ==3) {
                ssurv <- smat(x$pstate[,,i, drop=FALSE])
                if (!is.null(x$std.err))
                    std <- smat(x$std.err[,,i, drop=FALSE])
            }
            else {
                ssurv <- x$pstate[,i, drop=FALSE]
                if (!is.null(x$std.err)) std <- x$std.err[,i, drop=FALSE]
            }
        }
    }
    else {
        yzero <- TRUE
        ssurv <- as.matrix(x$surv)   # x$surv will have one column
        if (!is.null(x$std.err)) std <- as.matrix(x$std.err)
        # The fun argument only applies to single state survfit objects
        #  First deal with the special case of fun='cumhaz', which is here for
        #  backwards compatability; people should use the cumhaz argument
        if (!missing(fun) && is.character(fun) && fun=="cumhaz") {
            cumhaz <- TRUE
            if (!is.null(x$cumhaz)) {
                ssurv <- as.matrix(x$cumhaz)
                if (!is.null(x$std.chaz)) std <- as.matrix(x$std.chaz)
            } 
            else {
                ssurv <- as.matrix(-log(x$surv))
                if (!is.null(x$std.err)) {
                    if (x$logse) std <- as.matrix(x$std.err)
                    else std <- as.matrix(x$std.err/x$surv)
                }
             }
        }
    }

    # set up strata
    if (is.null(x$strata)) {
        nstrat <- 1
        stemp <- rep(1, length(x$time)) # same length as stime
    }
    else {
        nstrat <- length(x$strata)
        stemp <- rep(1:nstrat, x$strata) # same length as stime
    }
    ncurve <- nstrat * ncol(ssurv)
    conf.type <- match.arg(conf.type)
    if (conf.type=="none") conf.int <- FALSE
    if (conf.int== "none") conf.int <- FALSE
    if (conf.int=="only") {
        plot.surv <- FALSE
        conf.int <- TRUE
        }
    else plot.surv <- TRUE

    if (conf.int) {
        if (is.null(std)) stop("object does not have standard errors, CI not possible")
        if (cumhaz) {
            if (missing(conf.type)) conf.type="plain"
            temp <- survfit_confint(ssurv, std, logse=FALSE,
                                    conf.type, conf.level, ulimit=FALSE)
            supper <- as.matrix(temp$upper)
            slower <- as.matrix(temp$lower)
        }
        else if (is.null(x$upper)) {
            if (missing(conf.type) && !is.null(x$conf.type))
                conf.type <- x$conf.type
            temp <- survfit_confint(ssurv, x$std.err, logse= x$logse,
                                    conf.type, conf.level, ulimit=FALSE)
            supper <- as.matrix(temp$upper)
            slower <- as.matrix(temp$lower)
        }
        else {
            supper <- as.matrix(x$upper)
            slower <- as.matrix(x$lower)
        }
    } else supper <- slower <- NULL
    if (!inherits(x, "survfitms") && !cumhaz & !missing(fun)) {
        yzero <- FALSE
        if (is.character(fun)) {
            tfun <- switch(tolower(fun),
                           'log' = function(x) x,
                           'event'=function(x) 1-x,
                           'cumhaz'=function(x) -log(x),
                           'cloglog'=function(x) log(-log(x)),
                           'pct' = function(x) x*100,
                           'logpct'= function(x) 100*x,  #special case further below
                       'identity'= function(x) x,
                       'f' = function(x) 1-x,
                       's' = function(x) x,
                       'surv' = function(x) x,
                           stop("Unrecognized function argument")
                           )
            if (tolower(fun) %in% c("identity", "s") &&
                !inherits(x, "survfitms") && !cumhaz) yzero <- TRUE
        }
        else if (is.function(fun)) tfun <- fun
        else stop("Invalid 'fun' argument")
        
        ssurv <- tfun(ssurv )
        if (!is.null(supper)) {
            supper <- tfun(supper)
            slower <- tfun(slower)
        }
    }
    if (missing(mark.time) & !missing(mark)) mark.time <- TRUE
    if (missing(pch) && !missing(mark)) pch <- mark
    if (length(pch)==1 && is.character(pch)) pch <- strsplit(pch, "")[[1]]

    # Marks are not placed on confidence bands
    pch  <- rep(pch, length.out=ncurve)
    mcol <- rep(col, length.out=ncurve)
    if (is.numeric(mark.time)) mark.time <- sort(mark.time)

    # The actual number of curves is ncurve*3 if there are confidence bands,
    #  unless conf.times has been given.  Colors and line types in the latter
    #  match the curves
    # If the number of line types is 1 and lty is an integer, then use lty 
    #    for the curve and lty+1 for the CI
    # If the length(lty) <= length(ncurve), use the same color for curve and CI
    #   otherwise assume the user knows what they are about and has given a full
    #   vector of line types.
    # Colors and line widths work like line types, excluding the +1 rule.
    if (conf.int & is.null(conf.times)) {
        if (length(lty)==1 && is.numeric(lty))
            lty <- rep(c(lty, lty+1, lty+1), ncurve)
        else if (length(lty) <= ncurve)
            lty <- rep(rep(lty, each=3), length.out=(ncurve*3))
        else lty <- rep(lty, length.out= ncurve*3)
        
        if (length(col) <= ncurve) col <- rep(rep(col, each=3), length.out=3*ncurve)
        else col <- rep(col, length.out=3*ncurve)
        
        if (length(lwd) <= ncurve) lwd <- rep(rep(lwd, each=3), length.out=3*ncurve)
        else lwd <- rep(lwd, length.out=3*ncurve)
    }
    else {
        col  <- rep(col, length.out=ncurve)
        lty  <- rep(lty, length.out=ncurve)
        lwd  <- rep(lwd, length.out=ncurve)
    }
    # check consistency
    if (!missing(xlim)) {
        if (!missing(xmax)) warning("cannot have both xlim and xmax arguments, xmax ignored")
        if (!missing(firstx)) stop("cannot have both xlim and firstx arguments")
    }
    if (!missing(ylim)) {
        if (!missing(ymin)) stop("cannot have both ylim and ymin arguments")
    }

    # Do axis range computations

    if (!missing(xlim) && !is.null(xlim)) {
        tempx <- xlim
        if (xaxs == 'S') tempx[2] <- tempx[2] + diff(tempx)*1.04
    }
    else {
        temp <-  stime[is.finite(stime)]
        if (!missing(xmax) && missing(xlim)) temp <- temp[temp <= xmax]
        
        if (xaxs=='S') {
            #special x- axis style for survival curves
            if (xlog) tempx <- c(min(temp[temp>0]), max(temp)+ diff(temp)*1.04)
            else tempx <- c(min(temp), max(temp)) * 1.04
        }
        else if (xlog) tempx <- range(temp[temp > 0])
        else tempx <- range(temp)
    }  

    if (!missing(ylim) && !is.null(ylim)) tempy <- ylim
    else {
        skeep <- is.finite(stime) & stime >= tempx[1] & stime <= tempx[2]

        if (ylog) {
            if (!is.null(supper))
                tempy <- range(c(slower[is.finite(slower) & slower>0 & skeep], 
                                 supper[is.finite(supper) & skeep]))
            else tempy <-  range(ssurv[is.finite(ssurv)& ssurv>0 & skeep])
            if (tempy[2]==1) tempy[2] <- .99   # makes for a prettier axis
            if (any(c(ssurv, slower)[skeep] ==0)) {
                tempy[1] <- tempy[1]*.8
                ssurv[ssurv==0] <- tempy[1]
                if (!is.null(slower))  slower[slower==0] <- tempy[1]
            }
        }
        else {
            if (!is.null(supper)) 
                tempy <- range(c(supper[skeep], slower[skeep]), finite=TRUE, na.rm=TRUE)
            else tempy <- range(ssurv[skeep], finite=TRUE, na.rm= TRUE)
            if (yzero) tempy <- range(c(0, tempy))
        }
    }

    if (!missing(ymin)) tempy[1] <- ymin

    #
    # Draw the basic box
    #
    temp <- if (xaxs=='S') 'i' else xaxs
    plot(range(tempx, finite=TRUE, na.rm=TRUE)/xscale, 
         range(tempy, finite=TRUE, na.rm=TRUE)*yscale, 
         type='n', log=logax, xlab=xlab, ylab=ylab, xaxs=temp,...)
    if(yscale != 1) {
        if (ylog) par(usr =par("usr") -c(0, 0, log10(yscale), log10(yscale))) 
        else par(usr =par("usr")/c(1, 1, yscale, yscale))   
    }
    if (xscale !=1) {
        if (xlog) par(usr =par("usr") -c(log10(xscale), log10(xscale), 0,0)) 
        else par(usr =par("usr")*c(xscale, xscale, 1, 1))   
    }  
    if (xaxs=='i') resetclip <- FALSE
    else resetclip <- !(missing(xlim) & missing(ylim) & 
                        missing(xmax) & missing(firstx)& missing(ymin))

    if (resetclip) {
      # yes, do it
      if (xaxs=='S') tempx <- c(tempx[1], temp[1])
      clip(tempx[1], tempx[2], tempy[1], tempy[2])
      options(plot.survfit = list(plotclip=c(tempx, tempy), plotreset=par('usr')))
    }
    else options(plot.survfit = NULL)  #remove any notes from a prior plot
    # Create a step function, removing redundancies that sometimes occur in
    #  curves with lots of censoring.
    dostep <- function(x,y) {
        keep <- is.finite(x) & is.finite(y) 
        if (!any(keep)) return()  #all points were infinite or NA
        if (!all(keep)) {
            # these won't plot anyway, so simplify (CI values are often NA)
            x <- x[keep]
            y <- y[keep]
        }
        n <- length(x)
        if (n==1)       list(x=x, y=y)
        else if (n==2)  list(x=x[c(1,2,2)], y=y[c(1,1,2)])
        else {
            # replace verbose horizonal sequences like
            # (1, .2), (1.4, .2), (1.8, .2), (2.3, .2), (2.9, .2), (3, .1)
            # with (1, .2), (.3, .2),(3, .1).  
            #  They are slow, and can smear the looks of the line type.
            temp <- rle(y)$lengths
            drops <- 1 + cumsum(temp[-length(temp)])  # points where the curve drops

            #create a step function
            if (n %in% drops) {  #the last point is a drop
                xrep <- c(x[1], rep(x[drops], each=2))
                yrep <- rep(y[c(1,drops)], c(rep(2, length(drops)), 1))
            }
            else {
                xrep <- c(x[1], rep(x[drops], each=2), x[n])
                yrep <- c(rep(y[c(1,drops)], each=2))
            }
            list(x=xrep, y=yrep)
        }
    }

    drawmark <- function(x, y, mark.time, censor, cex, ...) {
        if (!is.numeric(mark.time)) {
            xx <- x[censor>0]
            yy <- y[censor>0]
            if (any(censor >1)) {  # tied death and censor, put it on the midpoint
                j <- pmax(1, which(censor>1) -1)
                i <- censor[censor>0]
                yy[i>1] <- (yy[i>1] + y[j])/2
            }
        }
        else { #interpolate
            xx <- mark.time
            yy <- approx(x, y, xx, method="constant", f=0)$y
        }
        points(xx, yy, cex=cex, ...)
    }
    type <- 's'
    c1 <- 1  # keeps track of the curve number
    c2 <- 1  # keeps track of the lty, col, etc
    xend <- yend <- double(ncurve)
    if (length(conf.offset) ==1) 
        temp.offset <- (1:ncurve - (ncurve+1)/2)* conf.offset* diff(par("usr")[1:2])
    else temp.offset <- rep(conf.offset, length=ncurve) *  diff(par("usr")[1:2])
    temp.cap    <-  conf.cap    * diff(par("usr")[1:2])

    for (j in 1:ncol(ssurv)) {
        for (i in unique(stemp)) {  #for each strata
            who <- which(stemp==i)

            # if n.censor is missing, then assume any line that does not have an
            #   event would not be present but for censoring, so there must have
            #   been censoring then
            # otherwise categorize is 0= no censor, 1=censor, 2=censor and death
            if (is.null(x$n.censor)) censor <- ifelse(x$n.event[who]==0, 1, 0)
            else censor <- ifelse(x$n.censor[who]==0, 0, 1 + (x$n.event[who] > 0))
            xx <- stime[who]
            yy <- ssurv[who,j]

            if (plot.surv) {
                if (type=='s')
                    lines(dostep(xx, yy), lty=lty[c2], col=col[c2], lwd=lwd[c2]) 
                else lines(xx, yy, type=type, lty=lty[c2], col=col[c2], lwd=lwd[c2])
                if (is.numeric(mark.time) || mark.time) 
                    drawmark(xx, yy, mark.time, censor, pch=pch[c1], col=mcol[c1],
                             cex=cex)
            }
            xend[c1] <- max(xx)
            yend[c1] <- yy[length(yy)]

            if (conf.int && !is.null(conf.times)) {
                # add vertical bars at the specified times
                x2 <- conf.times + temp.offset[c1]
                templow <- approx(xx, slower[who,j], x2,
                                  method='constant', f=1)$y
                temphigh<- approx(xx, supper[who,j], x2,
                                  method='constant', f=1)$y
                segments(x2, templow, x2, temphigh,
                          lty=lty[c2], col=col[c2], lwd=lwd[c2])
                if (conf.cap>0) {
                    segments(x2-temp.cap, templow, x2+temp.cap, templow,
                             lty=lty[c2], col=col[c2], lwd=lwd[c2] )
                    segments(x2-temp.cap, temphigh, x2+temp.cap, temphigh,
                              lty=lty[c2], col=col[c2], lwd=lwd[c2])
                }
               
            }
            c1 <- c1 +1
            c2 <- c2 +1

            if (conf.int && is.null(conf.times)) {
                if (type == 's') {
                    lines(dostep(xx, slower[who,j]), lty=lty[c2], 
                          col=col[c2],lwd=lwd[c2])
                    c2 <- c2 +1
                    lines(dostep(xx, supper[who,j]), lty=lty[c2], 
                          col=col[c2], lwd= lwd[c2])
                    c2 <- c2 + 1
                }
                else {
                    lines(xx, slower[who,j], lty=lty[c2], 
                          col=col[c2],lwd=lwd[c2], type=type) 
                    c2 <- c2 +1
                    lines(xx, supper[who,j], lty=lty[c2], 
                          col=col[c2], lwd= lwd[c2], type= type)
                    c2 <- c2 + 1
                }
             }

        }
    }
    lastx <- list(x=xend, y=yend)
    if (resetclip) {
        xx <- par("usr")
        clip(xx[1], xx[2], xx[3], xx[4])  # undo the clipping
    }
    invisible(lastx)
}

lines.survfit <- function(x, type='s', 
                          pch=3, col=1, lty=1, lwd=1,
                          cex=1,
                          mark.time=FALSE, 
                          fun,  conf.int=FALSE,  
                          conf.times, conf.cap=.005, conf.offset=.012,
                          conf.type=c('log',  'log-log',  'plain', 
                                  'logit', "arcsin"),
                          mark, noplot="(s0)", cumhaz=FALSE, ...) {
    x <- survfit0(x, x$start.time)

    xlog <- par("xlog")
    # The default for plot and lines is to add confidence limits
    #  if there is only one curve
    if (missing(conf.int) && missing(conf.times))  
        conf.int <- (!is.null(x$std.err) && prod(dim(x) ==1))

    if (missing(conf.times)) conf.times <- NULL   
    else {
        if (!is.numeric(conf.times)) stop('conf.times must be numeric')
        if (missing(conf.int)) conf.int <- TRUE
    }

    if (!missing(conf.int)) {
        if (is.numeric(conf.int)) {
            conf.level <- conf.int
            if (conf.level<0 || conf.level > 1)
                stop("invalid value for conf.int")
            if (conf.level ==0) conf.int <- FALSE
            else if (conf.level != x$conf.int) {
                x$upper <- x$lower <- NULL  # force recomputation
            }
            conf.int <- TRUE
        }
        else conf.level = 0.95
    }

    # Organize data into stime, ssurv, supper, slower
    stime <- x$time
    std   <- NULL
    yzero <- FALSE   # a marker that we have an "ordinary survival curve" with min 0
    smat <- function(x) {
        # the rest of the routine is simpler if everything is a matrix
        dd <- dim(x)
        if (is.null(dd)) as.matrix(x)
        else if (length(dd) ==2) x
        else matrix(x, nrow=dd[1])
    }

    if (cumhaz) {  # plot the cumulative hazard instead
        if (is.null(x$cumhaz)) 
            stop("survfit object does not contain a cumulative hazard")

        if (is.numeric(cumhaz)) {
            dd <- dim(x$cumhaz)
            if (is.null(dd)) nhazard <- 1
            else nhazard <- prod(dd[-1])

            if (cumhaz != floor(cumhaz)) stop("cumhaz argument is not integer")
            if (any(cumhaz < 1 | cumhaz > nhazard)) stop("subscript out of range")
            ssurv <- smat(x$cumhaz)[,cumhaz, drop=FALSE]
            if (!is.null(x$std.chaz)) std <- smat(x$std.chaz)[,cumhaz, drop=FALSE]
        }
        else if (is.logical(cumhaz)) {
            ssurv <- smat(x$cumhaz)
            if (!is.null(x$std.chaz)) std <- smat(x$std.chaz)
        }
        else stop("invalid cumhaz argument")
    }
    else if (inherits(x, "survfitms")) {
        i <- (x$states != noplot)
        if (all(i) || !any(i)) {
            # the !any is a failsafe, in case none are kept then ignore noplot
            ssurv <- smat(x$pstate)
            if (!is.null(x$std.err)) std <- smat(x$std.err)
        }
        else {
            i <- which(i)  # the states to keep
            # we have to be careful about subscripting
            if (length(dim(x$pstate)) ==3) {
                ssurv <- smat(x$pstate[,,i, drop=FALSE])
                if (!is.null(x$std.err))
                    std <- smat(x$std.err[,,i, drop=FALSE])
            }
            else {
                ssurv <- x$pstate[,i, drop=FALSE]
                if (!is.null(x$std.err)) std <- x$std.err[,i, drop=FALSE]
            }
        }
    }
    else {
        yzero <- TRUE
        ssurv <- as.matrix(x$surv)   # x$surv will have one column
        if (!is.null(x$std.err)) std <- as.matrix(x$std.err)
        # The fun argument only applies to single state survfit objects
        #  First deal with the special case of fun='cumhaz', which is here for
        #  backwards compatability; people should use the cumhaz argument
        if (!missing(fun) && is.character(fun) && fun=="cumhaz") {
            cumhaz <- TRUE
            if (!is.null(x$cumhaz)) {
                ssurv <- as.matrix(x$cumhaz)
                if (!is.null(x$std.chaz)) std <- as.matrix(x$std.chaz)
            } 
            else {
                ssurv <- as.matrix(-log(x$surv))
                if (!is.null(x$std.err)) {
                    if (x$logse) std <- as.matrix(x$std.err)
                    else std <- as.matrix(x$std.err/x$surv)
                }
             }
        }
    }

    # set up strata
    if (is.null(x$strata)) {
        nstrat <- 1
        stemp <- rep(1, length(x$time)) # same length as stime
    }
    else {
        nstrat <- length(x$strata)
        stemp <- rep(1:nstrat, x$strata) # same length as stime
    }
    ncurve <- nstrat * ncol(ssurv)
    conf.type <- match.arg(conf.type)
    if (conf.type=="none") conf.int <- FALSE
    if (conf.int== "none") conf.int <- FALSE
    if (conf.int=="only") {
        plot.surv <- FALSE
        conf.int <- TRUE
        }
    else plot.surv <- TRUE

    if (conf.int) {
        if (is.null(std)) stop("object does not have standard errors, CI not possible")
        if (cumhaz) {
            if (missing(conf.type)) conf.type="plain"
            temp <- survfit_confint(ssurv, std, logse=FALSE,
                                    conf.type, conf.level, ulimit=FALSE)
            supper <- as.matrix(temp$upper)
            slower <- as.matrix(temp$lower)
        }
        else if (is.null(x$upper)) {
            if (missing(conf.type) && !is.null(x$conf.type))
                conf.type <- x$conf.type
            temp <- survfit_confint(ssurv, x$std.err, logse= x$logse,
                                    conf.type, conf.level, ulimit=FALSE)
            supper <- as.matrix(temp$upper)
            slower <- as.matrix(temp$lower)
        }
        else {
            supper <- as.matrix(x$upper)
            slower <- as.matrix(x$lower)
        }
    } else supper <- slower <- NULL
    if (!inherits(x, "survfitms") && !cumhaz & !missing(fun)) {
        yzero <- FALSE
        if (is.character(fun)) {
            tfun <- switch(tolower(fun),
                           'log' = function(x) x,
                           'event'=function(x) 1-x,
                           'cumhaz'=function(x) -log(x),
                           'cloglog'=function(x) log(-log(x)),
                           'pct' = function(x) x*100,
                           'logpct'= function(x) 100*x,  #special case further below
                       'identity'= function(x) x,
                       'f' = function(x) 1-x,
                       's' = function(x) x,
                       'surv' = function(x) x,
                           stop("Unrecognized function argument")
                           )
            if (tolower(fun) %in% c("identity", "s") &&
                !inherits(x, "survfitms") && !cumhaz) yzero <- TRUE
        }
        else if (is.function(fun)) tfun <- fun
        else stop("Invalid 'fun' argument")
        
        ssurv <- tfun(ssurv )
        if (!is.null(supper)) {
            supper <- tfun(supper)
            slower <- tfun(slower)
        }
    }
    if (missing(mark.time) & !missing(mark)) mark.time <- TRUE
    if (missing(pch) && !missing(mark)) pch <- mark
    if (length(pch)==1 && is.character(pch)) pch <- strsplit(pch, "")[[1]]

    # Marks are not placed on confidence bands
    pch  <- rep(pch, length.out=ncurve)
    mcol <- rep(col, length.out=ncurve)
    if (is.numeric(mark.time)) mark.time <- sort(mark.time)

    # The actual number of curves is ncurve*3 if there are confidence bands,
    #  unless conf.times has been given.  Colors and line types in the latter
    #  match the curves
    # If the number of line types is 1 and lty is an integer, then use lty 
    #    for the curve and lty+1 for the CI
    # If the length(lty) <= length(ncurve), use the same color for curve and CI
    #   otherwise assume the user knows what they are about and has given a full
    #   vector of line types.
    # Colors and line widths work like line types, excluding the +1 rule.
    if (conf.int & is.null(conf.times)) {
        if (length(lty)==1 && is.numeric(lty))
            lty <- rep(c(lty, lty+1, lty+1), ncurve)
        else if (length(lty) <= ncurve)
            lty <- rep(rep(lty, each=3), length.out=(ncurve*3))
        else lty <- rep(lty, length.out= ncurve*3)
        
        if (length(col) <= ncurve) col <- rep(rep(col, each=3), length.out=3*ncurve)
        else col <- rep(col, length.out=3*ncurve)
        
        if (length(lwd) <= ncurve) lwd <- rep(rep(lwd, each=3), length.out=3*ncurve)
        else lwd <- rep(lwd, length.out=3*ncurve)
    }
    else {
        col  <- rep(col, length.out=ncurve)
        lty  <- rep(lty, length.out=ncurve)
        lwd  <- rep(lwd, length.out=ncurve)
    }

    do.clip <- options("plot.survfit")
    if (!is.null(xx <- do.clip$plotclip)) clip(xx[1], xx[2], xx[3], xx[4])

    # Create a step function, removing redundancies that sometimes occur in
    #  curves with lots of censoring.
    dostep <- function(x,y) {
        keep <- is.finite(x) & is.finite(y) 
        if (!any(keep)) return()  #all points were infinite or NA
        if (!all(keep)) {
            # these won't plot anyway, so simplify (CI values are often NA)
            x <- x[keep]
            y <- y[keep]
        }
        n <- length(x)
        if (n==1)       list(x=x, y=y)
        else if (n==2)  list(x=x[c(1,2,2)], y=y[c(1,1,2)])
        else {
            # replace verbose horizonal sequences like
            # (1, .2), (1.4, .2), (1.8, .2), (2.3, .2), (2.9, .2), (3, .1)
            # with (1, .2), (.3, .2),(3, .1).  
            #  They are slow, and can smear the looks of the line type.
            temp <- rle(y)$lengths
            drops <- 1 + cumsum(temp[-length(temp)])  # points where the curve drops

            #create a step function
            if (n %in% drops) {  #the last point is a drop
                xrep <- c(x[1], rep(x[drops], each=2))
                yrep <- rep(y[c(1,drops)], c(rep(2, length(drops)), 1))
            }
            else {
                xrep <- c(x[1], rep(x[drops], each=2), x[n])
                yrep <- c(rep(y[c(1,drops)], each=2))
            }
            list(x=xrep, y=yrep)
        }
    }

    drawmark <- function(x, y, mark.time, censor, cex, ...) {
        if (!is.numeric(mark.time)) {
            xx <- x[censor>0]
            yy <- y[censor>0]
            if (any(censor >1)) {  # tied death and censor, put it on the midpoint
                j <- pmax(1, which(censor>1) -1)
                i <- censor[censor>0]
                yy[i>1] <- (yy[i>1] + y[j])/2
            }
        }
        else { #interpolate
            xx <- mark.time
            yy <- approx(x, y, xx, method="constant", f=0)$y
        }
        points(xx, yy, cex=cex, ...)
    }
    c1 <- 1  # keeps track of the curve number
    c2 <- 1  # keeps track of the lty, col, etc
    xend <- yend <- double(ncurve)
    if (length(conf.offset) ==1) 
        temp.offset <- (1:ncurve - (ncurve+1)/2)* conf.offset* diff(par("usr")[1:2])
    else temp.offset <- rep(conf.offset, length=ncurve) *  diff(par("usr")[1:2])
    temp.cap    <-  conf.cap    * diff(par("usr")[1:2])

    for (j in 1:ncol(ssurv)) {
        for (i in unique(stemp)) {  #for each strata
            who <- which(stemp==i)

            # if n.censor is missing, then assume any line that does not have an
            #   event would not be present but for censoring, so there must have
            #   been censoring then
            # otherwise categorize is 0= no censor, 1=censor, 2=censor and death
            if (is.null(x$n.censor)) censor <- ifelse(x$n.event[who]==0, 1, 0)
            else censor <- ifelse(x$n.censor[who]==0, 0, 1 + (x$n.event[who] > 0))
            xx <- stime[who]
            yy <- ssurv[who,j]

            if (plot.surv) {
                if (type=='s')
                    lines(dostep(xx, yy), lty=lty[c2], col=col[c2], lwd=lwd[c2]) 
                else lines(xx, yy, type=type, lty=lty[c2], col=col[c2], lwd=lwd[c2])
                if (is.numeric(mark.time) || mark.time) 
                    drawmark(xx, yy, mark.time, censor, pch=pch[c1], col=mcol[c1],
                             cex=cex)
            }
            xend[c1] <- max(xx)
            yend[c1] <- yy[length(yy)]

            if (conf.int && !is.null(conf.times)) {
                # add vertical bars at the specified times
                x2 <- conf.times + temp.offset[c1]
                templow <- approx(xx, slower[who,j], x2,
                                  method='constant', f=1)$y
                temphigh<- approx(xx, supper[who,j], x2,
                                  method='constant', f=1)$y
                segments(x2, templow, x2, temphigh,
                          lty=lty[c2], col=col[c2], lwd=lwd[c2])
                if (conf.cap>0) {
                    segments(x2-temp.cap, templow, x2+temp.cap, templow,
                             lty=lty[c2], col=col[c2], lwd=lwd[c2] )
                    segments(x2-temp.cap, temphigh, x2+temp.cap, temphigh,
                              lty=lty[c2], col=col[c2], lwd=lwd[c2])
                }
               
            }
            c1 <- c1 +1
            c2 <- c2 +1

            if (conf.int && is.null(conf.times)) {
                if (type == 's') {
                    lines(dostep(xx, slower[who,j]), lty=lty[c2], 
                          col=col[c2],lwd=lwd[c2])
                    c2 <- c2 +1
                    lines(dostep(xx, supper[who,j]), lty=lty[c2], 
                          col=col[c2], lwd= lwd[c2])
                    c2 <- c2 + 1
                }
                else {
                    lines(xx, slower[who,j], lty=lty[c2], 
                          col=col[c2],lwd=lwd[c2], type=type) 
                    c2 <- c2 +1
                    lines(xx, supper[who,j], lty=lty[c2], 
                          col=col[c2], lwd= lwd[c2], type= type)
                    c2 <- c2 + 1
                }
             }

        }
    }
    lastx <- list(x=xend, y=yend)
    if (!is.null(xx <- do.clip$plotreset)) clip(xx[1], xx[2], xx[3], xx[4])
    invisible(lastx)
}

points.survfit <- function(x, fun, censor=FALSE,
                           col=1, pch, noplot="(s0)", cumhaz=FALSE, ...) {

    conf.int <- FALSE  # never draw these with 'points'
    x <- survfit0(x, x$start.time)

    # The default for plot and lines is to add confidence limits
    #  if there is only one curve
    if (missing(conf.int) && missing(conf.times))  
        conf.int <- (!is.null(x$std.err) && prod(dim(x) ==1))

    if (missing(conf.times)) conf.times <- NULL   
    else {
        if (!is.numeric(conf.times)) stop('conf.times must be numeric')
        if (missing(conf.int)) conf.int <- TRUE
    }

    if (!missing(conf.int)) {
        if (is.numeric(conf.int)) {
            conf.level <- conf.int
            if (conf.level<0 || conf.level > 1)
                stop("invalid value for conf.int")
            if (conf.level ==0) conf.int <- FALSE
            else if (conf.level != x$conf.int) {
                x$upper <- x$lower <- NULL  # force recomputation
            }
            conf.int <- TRUE
        }
        else conf.level = 0.95
    }

    # Organize data into stime, ssurv, supper, slower
    stime <- x$time
    std   <- NULL
    yzero <- FALSE   # a marker that we have an "ordinary survival curve" with min 0
    smat <- function(x) {
        # the rest of the routine is simpler if everything is a matrix
        dd <- dim(x)
        if (is.null(dd)) as.matrix(x)
        else if (length(dd) ==2) x
        else matrix(x, nrow=dd[1])
    }

    if (cumhaz) {  # plot the cumulative hazard instead
        if (is.null(x$cumhaz)) 
            stop("survfit object does not contain a cumulative hazard")

        if (is.numeric(cumhaz)) {
            dd <- dim(x$cumhaz)
            if (is.null(dd)) nhazard <- 1
            else nhazard <- prod(dd[-1])

            if (cumhaz != floor(cumhaz)) stop("cumhaz argument is not integer")
            if (any(cumhaz < 1 | cumhaz > nhazard)) stop("subscript out of range")
            ssurv <- smat(x$cumhaz)[,cumhaz, drop=FALSE]
            if (!is.null(x$std.chaz)) std <- smat(x$std.chaz)[,cumhaz, drop=FALSE]
        }
        else if (is.logical(cumhaz)) {
            ssurv <- smat(x$cumhaz)
            if (!is.null(x$std.chaz)) std <- smat(x$std.chaz)
        }
        else stop("invalid cumhaz argument")
    }
    else if (inherits(x, "survfitms")) {
        i <- (x$states != noplot)
        if (all(i) || !any(i)) {
            # the !any is a failsafe, in case none are kept then ignore noplot
            ssurv <- smat(x$pstate)
            if (!is.null(x$std.err)) std <- smat(x$std.err)
        }
        else {
            i <- which(i)  # the states to keep
            # we have to be careful about subscripting
            if (length(dim(x$pstate)) ==3) {
                ssurv <- smat(x$pstate[,,i, drop=FALSE])
                if (!is.null(x$std.err))
                    std <- smat(x$std.err[,,i, drop=FALSE])
            }
            else {
                ssurv <- x$pstate[,i, drop=FALSE]
                if (!is.null(x$std.err)) std <- x$std.err[,i, drop=FALSE]
            }
        }
    }
    else {
        yzero <- TRUE
        ssurv <- as.matrix(x$surv)   # x$surv will have one column
        if (!is.null(x$std.err)) std <- as.matrix(x$std.err)
        # The fun argument only applies to single state survfit objects
        #  First deal with the special case of fun='cumhaz', which is here for
        #  backwards compatability; people should use the cumhaz argument
        if (!missing(fun) && is.character(fun) && fun=="cumhaz") {
            cumhaz <- TRUE
            if (!is.null(x$cumhaz)) {
                ssurv <- as.matrix(x$cumhaz)
                if (!is.null(x$std.chaz)) std <- as.matrix(x$std.chaz)
            } 
            else {
                ssurv <- as.matrix(-log(x$surv))
                if (!is.null(x$std.err)) {
                    if (x$logse) std <- as.matrix(x$std.err)
                    else std <- as.matrix(x$std.err/x$surv)
                }
             }
        }
    }

    # set up strata
    if (is.null(x$strata)) {
        nstrat <- 1
        stemp <- rep(1, length(x$time)) # same length as stime
    }
    else {
        nstrat <- length(x$strata)
        stemp <- rep(1:nstrat, x$strata) # same length as stime
    }
    ncurve <- nstrat * ncol(ssurv)
    if (!inherits(x, "survfitms") && !cumhaz & !missing(fun)) {
        yzero <- FALSE
        if (is.character(fun)) {
            tfun <- switch(tolower(fun),
                           'log' = function(x) x,
                           'event'=function(x) 1-x,
                           'cumhaz'=function(x) -log(x),
                           'cloglog'=function(x) log(-log(x)),
                           'pct' = function(x) x*100,
                           'logpct'= function(x) 100*x,  #special case further below
                       'identity'= function(x) x,
                       'f' = function(x) 1-x,
                       's' = function(x) x,
                       'surv' = function(x) x,
                           stop("Unrecognized function argument")
                           )
            if (tolower(fun) %in% c("identity", "s") &&
                !inherits(x, "survfitms") && !cumhaz) yzero <- TRUE
        }
        else if (is.function(fun)) tfun <- fun
        else stop("Invalid 'fun' argument")
        
        ssurv <- tfun(ssurv )
        if (!is.null(supper)) {
            supper <- tfun(supper)
            slower <- tfun(slower)
        }
    }
    do.clip <- options("plot.survfit")
    if (!is.null(xx <- do.clip$plotclip)) clip(xx[1], xx[2], xx[3], xx[4])

    if (ncurve==1 || (length(col)==1 && missing(pch))) {
        if (censor) points(stime, ssurv, ...)
        else points(stime[x$n.event>0], ssurv[x$n.event>0], ...)
    }
    else {
        c2 <- 1  #cycles through the colors and characters
        col <- rep(col, length=ncurve)
        if (!missing(pch)) {
            if (length(pch)==1)
                pch2 <- rep(strsplit(pch, '')[[1]], length=ncurve)
            else pch2 <- rep(pch, length=ncurve)
        }
        for (j in 1:ncol(ssurv)) {
            for (i in unique(stemp)) {
                if (censor) who <- which(stemp==i)
                else who <- which(stemp==i & x$n.event >0)
                if (missing(pch))
                    points(stime[who], ssurv[who,j], col=col[c2], ...)
                else
                    points(stime[who], ssurv[who,j], col=col[c2], 
                           pch=pch2[c2], ...) 
                c2 <- c2+1
            }
        }
    }
    if (!is.null(xx <- do.clip$plotreset)) clip(xx[1], xx[2], xx[3], xx[4])
}
