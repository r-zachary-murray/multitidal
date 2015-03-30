      subroutine polytr(order,mtot,rhoc,polyk,mu,mode,
     1                  x,y,yp,radius,rho,mass,prss,ebind,rhom,
     2                  ztemp,zbeta,exact,xsurf,ypsurf,n,iend,ipos)
      implicit none
      include 'const.dek'

!..this routine computes the physical properties of a polytropic star.
!..see chandrasekhars "stellar structure"


!..input :
!..order = order of the polytrope; gamma = 1 + 1/order
!..mode  = 1;  total mass and central density are given. 
!..            the polytropic constant is then computed.
!..      = 2;  total mass and polytropic constant are given. 
!..            the central density is then computed.
!..      = 3;  central density and polytropic constant given.
!..            the total mass is computed.
!..mu    = molecular weight
!..n     = dimension of the output arrays


!..output:
!..x = dimensionless radial coordinate
!..y = dimensionless density coordinate
!..yp = dimensionless derivative dx/dy
!..radius = radial coordinate (solar units)
!..density = mass density in g/cm**3
!..mass    = mass interior to the radial coordinate
!..prss    = pressure in erg/cm**3
!..ebind   = binding energy in erg/gr
!..rhom    = ratio of mean desnity to central density
!..ztemp   = temperature in K
!..zbeta   = ratio of gas to toal pressure
!..exact   = exact solution of n = 0, 1, or 5
!..xsurf   = x value where y is zero, dimensionless surface of the star
!..ypsurf  = dx/dy at the dimensionless suurface of the star
!..iend    = total number of solution points
!..ipos    = number of solution points with y > 0


!..declare the pass
      integer          n,iend,ipos,mode
      double precision order,mtot,rhoc,polyk,mu,
     1                 x(n),y(n),yp(n),radius(n),rho(n),mass(n),prss(n),
     2                 ebind(n),rhom(n),ztemp(n),zbeta(n),exact(n),
     3                 xsurf,ypsurf


!..locals variables
      external          lanemd,rkqc,tlane,cross
      logical           succes
      integer           i,k,mm,xdim,ydim,nok,nbad,iprint,iat
      parameter         (xdim=600, ydim=2)

      double precision  xrk(xdim),yrk(ydim,xdim),bc(ydim),stptry,
     1                  stpmin,stpmax,tol,odescal,lo,hi,zbrent,start,
     2                  sstop,xx,rscale,secday,f1,f2,f3


!..communication with routine lanemd and routine tlane
      double precision  oord,ppres,den,mmu,beta
      common   /poly1/  oord,ppres,den,mmu,beta



!..communication with routine cross
      integer           jpmax,jp
      parameter         (jpmax=20)
      double precision  xa(jpmax),ya(jpmax),ypa(jpmax),yps
      common   /zsurf/  xa,ya,ypa,yps,jp



!..various constants
      double precision  twoth,fpi,fpig
      parameter        (twoth  = 2.0d0/3.0d0,
     1                  fpi    = 4.0d0 * pi, 
     2                  fpig   = fpi * g)




!..initialize
       oord  = order
       mmu   = mu
       lo    = 1.0d2
       hi    = 1.0d9


!..set the initial conditions 
!..nominally x = 0 bc(1) = 0.0d0 and bc(2) = 1.0d0
!..start away from the x=0 singularity and move the boundary conditions as well

      start   = 1.0d-6
      call le_series(order,start,bc(2),bc(1))


!..set the numerical control parameters
!..integration for order=0 is so good that it makes ugly plots
!..so enforce a maximum step size 

      stptry  = 1.0d-8
      stpmin  = 1.0d-12
      stpmax  = 1.0e24
      if (order .eq. 0.0) stpmax = 0.05
      sstop   = 50.0d0
      tol     = 1.0d-8
      odescal = 1.0d0
      iprint  = 0


!..integrate to get the dimensionless solution

      call podeint(start,stptry,stpmin,sstop,bc,
     1            tol,stpmax,xdim,
     2            xrk,yrk,xdim,ydim,xdim,ydim,
     3            nok,nbad,k,odescal,iprint,
     4            lanemd,rkqc)


!..set the total number of points in the solution
      iend = min(k,n)


!..set the number of points with y > 0
      do i=1,iend
       if (yrk(2,i) .le. 0.0) goto 21
       ipos = i
      end do
 21   continue


!..transfer the solution in the output arrays
      do i=1,iend
       x(i)  = xrk(i)
       y(i)  = yrk(2,i)
       yp(i) = yrk(1,i)
      end do


!..find the zero crossing value
!..jp is the number of points to use in the polynomial fit

      if (ipos .lt. iend) then
       jp = 6
       iat = max(1,min(ipos - jp/2 + 1,iend - jp + 1))
       do mm=1,jp
        xa(mm)  = x(iat  + (mm-1))
        ya(mm)  = y(iat  + (mm-1))
        ypa(mm) = yp(iat + (mm-1))
       enddo
       xsurf  = zbrent(cross,xa(1),xa(jp),tol)
       ypsurf = yps
      else
       xsurf  = x(ipos)
       ypsurf = yp(ipos)
      end if





!..the rest of this routine figures out the physical, dimensional solution

!..for order < 1
!..serious problems of computing the physical properties for order < 1.
!..cases of real physical interest always have order > 1. 
!..see chandra pg 106, last part of section 8 for an amusing commentary.
!..in this case, only return the dimensionless solution x and y. 

      if (order .le. 1.0) then
       do i=1,ipos
        if (order .eq. 0.0) then
         exact(i)  = 1.0d0 - x(i)*x(i)/6.0d0
        else if (order .eq. 1.0) then
         exact(i)  = dsin(x(i))/x(i)
        end if
       enddo
       !return
      end if



!..for order > 1
      f1 = -fpi * xsurf * xsurf * ypsurf
      f2 = (order + 1.0d0) /fpig
      f3 = (3.0d0 - order)/(2.0d0 * order) 


!..total mass and central density given. compute the polytropic k
      if (mode .eq. 1) then
       ! polyk is not actually used because it can't be used for
       ! polytropes with order < 1. This is because the density
       ! is raised to a large power.

       polyk = 1.0d0/f2 * (mtot*msol/(f1*rhoc**f3))**twoth


!..total mass and polytropic k given. compute the central density
      else if (mode .eq. 2) then
       if (f3 .eq. 0.0) then 
        rhoc = 1.0d0
       else
        rhoc = ( mtot*msol/(f1 * (f2*polyk)**1.5d0 ) )**(1.0d0/f3)
       endif


!..central density and polytropic k given. compute the total mass.
      else if (mode .eq. 3) then
       mtot = f1/msol * (f2*polyk)**1.5d0 * rhoc**f3  

!..a bad mode
      else 
       stop 'unknown mode in routine polytr'
      end if



!..the constant radial scale factor
      ! Disabled by JFG
      !rscale = dsqrt( f2*polyk * rhoc**(1.0d0/order - 1.0d0) )
      rscale = dabs(mtot*msol/f1/rhoc)**(1.d0/3.d0)
      


!..start the output loop
      do i=1,ipos

!..radius
       radius(i) = rscale * x(i)

!..density; copy the value to common block
       rho(i) = rhoc * y(i)**order
       den    = rho(i)

!..the mass interior to the radius
       mass(i) = fpi * rhoc * rscale**3 * (-x(i)*x(i)*yp(i))

!..the total pressure
       ! Disabled by JFG
       !prss(i)= polyk * rho(i)**(1.0d0 + 1.0d0/order)
       prss(i) = (rscale*rhoc)**2*y(i)**(order+1.d0)/f2
       ppres  = prss(i)

!..the gravitational binding energy (take care of infinity at n=5)
       ebind(i)  = -1.0e30
       if (order .ne. 5.0  .and.  radius(i) .ne. 0.0) 
     1  ebind(i) = (3.0d0*mass(i)*mass(i)*g)/((order - 5.0d0)*radius(i))

!..the central to mean density ratio;if n=5 output the exact solution
       rhom(i)   = 1.0d0
       if (yp(i) .ne. 0.0)  rhom(i) = -x(i) / (3.0d0 * yp(i))
       if (order .eq. 5.0) exact(i) = 1.0d0/dsqrt(1.0d0+x(i)*x(i)/3.0d0)

!..the temperature is given by a root find on the gas + radiation pressures
!..be sure the solution is bracketed

       call zbrac(tlane,lo,hi,succes)
       if (.not.succes) then
        write(6,35) 'den=',den,' pres=',ppres,' lo=',lo,' hi=',hi
35      format(1x,4(a,1pe11.3))
        write(6,*) 'cannot bracket temperature, but carrying on'
        ztemp(i) = 0.0d0
        zbeta(i) = 0.0d0
        lo       = 1.0d2
        hi       = 1.0d9

!..reset the search limits for the next trip
       else
        ztemp(i)= zbrent(tlane,lo,hi,tol)
        lo      = 0.1d0 * ztemp(i)
        hi      = 2.0d0 * ztemp(i)
        zbeta(i) = beta
       end if

!..back for another point or bail
      enddo
      return
      end







      subroutine lanemd(x,y,dydx)
      implicit none

!..this routine evaluates the lane-emden equation of order n

!..declare
      double precision x,y(*),dydx(*),rz
      double complex   z


!..communication with other routines
      double precision  oord,ppres,den,mmu,beta
      common   /poly1/  oord,ppres,den,mmu,beta


!..allow for a negative y, although not physical, it exists
!..mathematically, and is useful for determining surface quantities

      z = dcmplx(y(2),0.0d0) 
      rz = abs(z**oord)

      dydx(1) = -2.0d0 * y(1)/x - rz
      dydx(2) = y(1)
      return
      end





      double precision function cross(xsurf)
      implicit none

!..this routine is used by a root finder to find the x coordinate 
!..where the y coordinate goes to zero. that is, find the surface of the star.

!..declare the pass
      double precision xsurf

!..local variables
      double precision ysurf,dy

!..communication with routine cross
      integer           jpmax,jp
      parameter         (jpmax=20)
      double precision  xa(jpmax),ya(jpmax),ypa(jpmax),yps
      common   /zsurf/  xa,ya,ypa,yps,jp


      call polint(xa,ya,jp,xsurf,ysurf,dy)
      call polint(xa,ypa,jp,xsurf,yps,dy)


!..we seek the zero of this function
      cross = ysurf
      return
      end 






      double precision function tlane(t)
      implicit none
      include 'const.dek'

!..given the total pressure, density, and mean molecular weight
!..this routine is used by a root finder to find the temperature 
!..at which the sum of the ideal gas and radiation pressures is 
!..equal to the total pressure given by the lane-emden solution.

!..declare
      double precision t

!..communication with other routines
      double precision  oord,ppres,den,mmu,beta
      common   /poly1/  oord,ppres,den,mmu,beta


!..ratio of gas to total pressure
      beta  = (avo*kerg*den*t)/(mmu*ppres)  

!..we seek the zero of this function
      !write(6,*) 'asol=',asol,' ppres=',ppres,' t=',t,' beta=',beta
      tlane = (asol*t*t*t*t)/(3.0d0*ppres) + beta - 1.0d0
      !write(6,*) 'tlane=',tlane
      return
      end 







      subroutine le_series(xn,z,f,fp)
      implicit none

!..given the order xn and a point z of the lane-emden equation,
!..this routine returns value and derivative of the function
!..through and an order 14 seriees expansion.

!..mathematica expansion from david reiss
!..http://www.scientificarts.com/laneemden/Links/laneemden_lnk_1.html

!..declare the pass
      double precision xn,z,f,fp

!..local variables
      double precision xn2,xn3,xn4,p6,p8,p10,p12,
     1                 z2,z3,z4,z5,z6,z7,z8,z9,z10,z11,z12

      double precision c2,c4,c6,c8,c10,c12
      parameter       (c2  = 1.0d0/6.0d0,
     1                 c4  = 1.0d0/120.0d0,
     2                 c6  = 1.0d0/15120.0d0,
     3                 c8  = 1.0d0/3265920.0d0,
     4                 c10 = 1.0d0/1796256000.0d0,
     5                 c12 = 1.0d0/840647808000.0d0)



!..here we go
      xn2 = xn * xn
      xn3 = xn * xn2
      xn4 = xn * xn3

      p6  = xn*(8.0d0*xn - 5.0d0)
      p8  = xn*(122.0d0*xn2 - 183.0d0*xn + 70.0d0)
      p10 = xn*(5032.0d0*xn3 - 12642.0d0*xn2 + 10805.0d0*xn - 3150.0d0)
      p12 = xn*(183616.0d0*xn4 - 663166.0d0*xn3 + 915935.0d0*xn2 
     1                         - 574850.0d0*xn + 138600.0d0)

      z2  = z * z
      z3  = z * z2
      z4  = z * z3
      z5  = z * z4
      z6  = z * z5
      z7  = z * z6
      z8  = z * z7
      z9  = z * z8
      z10 = z * z9
      z11 = z * z10
      z12 = z * z11


!..the series expansion and its derivative with respect to z
      f  =  1.0d0 - c2*z2 + c4*z4*xn - c6*z6*p6
     1      + c8*z8*p8 - c10*z10*p10 + c12*z12*p12

      fp = -2.0d0*c2*z + 4.0d0*c4*z3*xn - 6.0d0*z5*p6
     1     + 8.0d0*c8*z7*p8 - 10.0d0*c10*z9*p10 + 12.0d0*c12*z11*p12

      return
      end








      subroutine podeint(start,stptry,stpmin,stopp,bc,
     1                   eps,stpmax,kmax, 
     2                   xrk,yrk,xphys,yphys,xlogi,ylogi,
     3                   nok,nbad,kount,odescal,iprint,
     4                   derivs,steper)  
      implicit none


!..basic ode integrator from numerical recipes.
!..special hooks added for polytropes.

!..declare  
      external         derivs,steper
      integer          nok,nbad,nmax,nstpmax,kmax,kount,xphys,
     1                 yphys,xlogi,ylogi,iprint,i,j,nstp
      parameter        (nmax = 20, nstpmax=10000)  
      double precision bc(yphys),stptry,stpmin,eps,stopp,start, 
     1                 yscal(nmax),y(nmax),dydx(nmax),  
     2                 stpmax,xrk(xphys),yrk(yphys,xphys),odescal, 
     3                 x,xsav,h,hdid,hnext,zero,one,tiny,ttiny
      parameter        (zero=0.0, one=1.0, tiny=1.0e-30, ttiny=1.0e-15)


!..here are the format statements for printouts as we integrate
100   format(1x,i4,1p10e12.4)



!..initialize   
      if (ylogi .gt. yphys) stop 'ylogi > yphys in routine odeint'
      if (yphys .gt. nmax)  stop 'yphys > nmax in routine odeint'
      x     = start   
      h     = sign(stptry,stopp-start) 
      nok   = 0 
      nbad  = 0
      kount = 0   


!..store the first step 
      do i=1,ylogi
       y(i) = bc(i)  
      enddo
      xsav = x


!..take at most nstpmax steps
      do nstp=1,nstpmax
       call derivs(x,y,dydx)


!..scaling vector used to monitor accuracy  
       do i=1,ylogi
        yscal(i) = abs(y(i)) + abs(h * dydx(i)) + tiny
       enddo


!..store intermediate results   
       if (kmax .gt. 0) then
        if ( kount .lt. (kmax-1) ) then  
         kount         = kount+1  
         xrk(kount)    = x   
         do i=1,ylogi 
          yrk(i,kount) = y(i)
         enddo
         if (iprint .eq. 1) then
          write(6,100) kount,xrk(kount),(yrk(j,kount), j=1,ylogi)
         end if
        end if
        xsav=x 
       end if



!..if the step can overshoot the stop point then cut it
       if ((x+h-stopp)*(x+h-start).gt.zero) h = stopp - x  


!..do an integration step
       call steper(y,dydx,ylogi,x,h,eps,yscal,hdid,hnext,derivs)   
       if (hdid.eq.h) then
        nok = nok+1   
       else 
        nbad = nbad+1 
       end if


!..bail if the solution gets "too" negative, we only need a negative y values
!..points to determine the zero crossing, the radius of the star

       if (y(2) .lt. -0.1) return


!..this is the normal exit point, save the final step   
       if (nstp.eq.nstpmax .or. (x-stopp)*(stopp-start) .ge. zero) then
        do i=1,ylogi  
         bc(i) = y(i) 
        enddo
        if (kmax.ne.0) then   
         kount         = kount+1  
         xrk(kount)    = x   
         do i=1,ylogi 
          yrk(i,kount) = y(i) 
         enddo
         if (iprint .eq. 1) then
           write(6,100) kount,xrk(kount),(yrk(j,kount), j=1,ylogi)
         end if
        end if
        return  
       end if


!..set the step size for the next iteration; stay above stpmin
       h = min(hnext,stpmax)
       if (abs(hnext).lt.stpmin) stop 'hnext < stpmin in odeint'


!..back for another iteration or death
      enddo
      write(6,*) '> than nstpmax steps required in odeint' 
      return
      end







      subroutine rkqc(y,dydx,n,x,htry,eps,yscal,hdid,hnext,derivs)  
      implicit none

!..fifth order, step doubling, runge-kutta ode integrator with monitering of 
!..local truncation errors. input are the vector y of length n, which has a 
!..known the derivative dydx at the point x, the step size to be attempted 
!..htry, the required accuracy eps, and the vector yscal against which the 
!..error is to be scaled.  on output, y and x are replaced by their new values,
!..hdid is the step size that was actually accomplished, and hnext is the 
!..estimated next step size. derivs is a user supplied routine that computes 
!..the right hand side of the first order system of odes. plug into odeint.

!..declare  
      external         derivs   
      integer          n,nmax,i 
      parameter        (nmax = 2000)  
      double precision x,htry,eps,hdid,hnext,y(n),dydx(n),yscal(n), 
     1                 ytemp(nmax),ysav(nmax),dysav(nmax),fcor,safety,
     2                 errcon,pgrow,pshrnk,xsav,h,hh,errmax 
      parameter        (fcor=1.0d0/15.0d0, pgrow = -0.2d0, 
     1                  pshrnk = -0.25d0,  safety=0.9d0,  errcon=6.0e-4)


!..note errcon = (4/safety)**(1/pgrow)  
!..nmax is the maximum number of differential equations

!..save the initial values 
      h      = htry
      xsav   =  x
      do i=1,n   
       ysav(i)  = y(i)
       dysav(i) = dydx(i)
      enddo


!..take two half steps  
1     hh = 0.5d0*h  
      call rk4(ysav,dysav,n,xsav,hh,ytemp,derivs)   
      x  = xsav + hh 
      call derivs(x,ytemp,dydx) 
      call rk4(ytemp,dydx,n,x,hh,y,derivs)  
      x  = xsav + h  
      if (x .eq. xsav) stop 'stepsize not significant in rkqc' 


!..now take the large step  
      call rk4(ysav,dysav,n,xsav,h,ytemp,derivs)


!..ytemp is the error estimate  
      errmax = 0.0d0
      do i=1,n   
       ytemp(i) = y(i) - ytemp(i)  
       errmax   = max(errmax,abs(ytemp(i)/yscal(i)))   
      enddo
      errmax     = errmax/eps 


!..truncation error too big, reduce the step size and try again 
      if (errmax .gt. 1.0) then
       h = safety * h * (errmax**pshrnk) 
       go to  1  


!..truncation within limits, compute the size of the next step  
      else  
       hdid = h  
       if (errmax.gt.errcon) then
        hnext = safety * h * (errmax**pgrow)
       else
        hnext = 4.0d0 * h
       end if   
      end if 


!..mop up the fifth order truncation error  
      do i=1,n   
       y(i) = y(i) + ytemp(i)*fcor 
      enddo
      return
      end





       subroutine rk4(y,dydx,n,x,h,yout,derivs) 
       implicit none

!..given values for the variables y(1:n) and their derivatives dydx(1:n) known
!..at x, use the fourth order runge-kutta method to advance the solution over
!..an interval h and return the incremented variables in yout(1:n) (which need
!..not be a distinct array from y). one supplies the routine derivs which 
!..evaluates the right hand side of the ode's.   

!..declare  
       external          derivs 
       integer           n,nmax,i   
       parameter         (nmax = 2000)  
       double precision  x,h,y(n),dydx(n),yout(n),
     1                   yt(nmax),dyt(nmax),dym(nmax),
     2                   hh,h6,xh   


!..initialize the step sizes and weightings 
       hh = h*0.5d0
       h6 = h/6.0d0 
       xh = x + hh  

!..the first step   
       do i=1,n  
        yt(i) = y(i) + hh*dydx(i)  
       enddo


!..the second step  
       call derivs(xh,yt,dyt)   
       do i=1,n  
        yt(i) = y(i) + hh*dyt(i)   
       enddo


!..the third step   
       call derivs(xh,yt,dym)   
       do i=1,n  
        yt(i)  = y(i) + h*dym(i)
        dym(i) = dyt(i) + dym(i)   
       enddo


!..the fourth step and accumulate the increments with the proper weights
       call derivs(x+h,yt,dyt)  
       do i=1,n  
        yout(i) = y(i) + h6*(dydx(i) +dyt(i) + 2.0d0*dym(i)) 
       enddo
       return   
       end  





      subroutine zbrac(func,x1,x2,succes)   
      implicit none

!..given a function func and an initial guessed range x1 to x2, the routine 
!..expands the range geometrically until a root is bracketed by the returned
!..values x1 and x2 (in which case succes returns as .true.) or until the range
!..becomes unacceptably large (in which case succes returns as .false.).    
!..success  guaranteed for a function which has opposite sign for sufficiently
!..large and small arguments.   

!..declare 
      external          func
      logical           succes  
      integer           ntry,j  
      parameter         (ntry=500)
      double precision  func,x1,x2,factor,f1,f2 
      parameter         (factor = 1.6d0)
!.. 
      if (x1 .eq. x2) stop ' x1 = x2 in routine zbrac'
      f1 = func(x1) 
      f2 = func(x2) 
      succes = .true.   
      do j=1,ntry
       if (f1*f2 .lt. 0.0) return   
       if (abs(f1) .lt. abs(f2)) then   
        x1 = x1 + factor * (x1-x2)
        f1 = func(x1)   
       else 
        x2 = x2 + factor * (x2-x1)
        f2 = func(x2)   
       end if   
      enddo
      succes = .false.  
      return
      end   





      double precision function zbrent(func,x1,x2,tol)  
      implicit none

!..using brent's method this routine finds the root of a function func between
!..the limits x1 and x2. the root is when accuracy is less than tol 

!..declare
      external          func
      integer           itmax,iter  
      parameter         (itmax=100)  
      double precision  func,x1,x2,tol,a,b,c,d,e,fa,
     1                  fb,fc,xm,tol1,p,q,r,s,eps   
      parameter         (eps=3.0d-15)  

!..note: eps the the machine floating point precision


!..initialize
      a  = x1
      b  = x2
      fa = func(a)  
      fb = func(b)  
      if ( (fa .gt. 0.0  .and. fb .gt. 0.0)  .or.
     1     (fa .lt. 0.0  .and. fb .lt. 0.0)       ) then
       write(6,100) x1,fa,x2,fb
100    format(1x,' x1=',1pe11.3,' f(x1)=',1pe11.3,/,
     1        1x,' x2=',1pe11.3,' f(x2)=',1pe11.3)
       stop 'root not bracketed in routine zbrent'   
      end if
      c  = b
      fc = fb   


!..start the iteration loop
      do iter =1,itmax   

!..rename a,b,c and adjusting bound interval d  
       if ( (fb .gt. 0.0  .and. fc .gt. 0.0)  .or.
     1      (fb .lt. 0.0  .and. fc .lt. 0.0)      ) then
        c  = a   
        fc = fa 
        d  = b-a 
        e  = d   
       end if   
       if (abs(fc) .lt. abs(fb)) then   
        a  = b   
        b  = c   
        c  = a   
        fa = fb 
        fb = fc 
        fc = fa 
       end if   
       tol1 = 2.0d0 * eps * abs(b) + 0.5d0 * tol
       xm   = 0.5d0 * (c-b) 


!..convergence check
       if (abs(xm) .le. tol1 .or. fb .eq. 0.0) then 
        zbrent = b  
        return  
       end if   


!..attempt quadratic interpolation  
       if (abs(e) .ge. tol1 .and. abs(fa) .gt. abs(fb)) then
        s = fb/fa   
        if (a .eq. c) then  
         p = 2.0d0 * xm * s   
         q = 1.0d0 - s 
        else
         q = fa/fc  
         r = fb/fc  
         p = s * (2.0d0 * xm * q *(q-r) - (b-a)*(r - 1.0d0))  
         q = (q - 1.0d0) * (r - 1.0d0) * (s - 1.0d0)
        end if  


!..check if in bounds   
        if (p .gt. 0.0) q = -q   
        p = abs(p)  

!..accept interpolation 
        if (2.0d0*p .lt. min(3.0d0*xm*q - abs(tol1*q),abs(e*q))) then   
         e = d  
         d = p/q

!..or bisection 
        else
         d = xm 
         e = d  
        end if  

!..bounds decreasing to slowly use bisection
       else 
        d = xm  
        e = d   
       end if   

!..move best guess to a 
       a  = b
       fa = fb  
       if (abs(d) .gt. tol1) then   
        b = b + d   
       else 
        b = b + sign(tol1,xm)   
       end if   
       fb = func(b) 

      enddo
      stop 'too many iterations in routine zbrent'  
      end   





      subroutine polint(xa,ya,n,x,y,dy)
      implicit none

!..given arrays xa and ya of length n and a value x, this routine returns a 
!..value y and an error estimate dy. if p(x) is the polynomial of degree n-1
!..such that ya = p(xa) ya then the returned value is y = p(x) 


!..declare the pass
      integer          n
      double precision xa(n),ya(n),x,y,dy


!..local variables
      integer          nmax,ns,i,m
      parameter        (nmax=10)
      double precision c(nmax),d(nmax),dif,dift,ho,hp,w,den


!..find the index ns of the closest table entry; initialize the c and d tables
      ns  = 1
      dif = abs(x - xa(1))
      do i=1,n
       dift = abs(x - xa(i))
       if (dift .lt. dif) then
        ns  = i
        dif = dift
       end if
       c(i)  = ya(i)
       d(i)  = ya(i)
      enddo

!..first guess for y
      y = ya(ns)

!..for each column of the table, loop over the c's and d's and update them
      ns = ns - 1
      do m=1,n-1
       do i=1,n-m
        ho   = xa(i) - x
        hp   = xa(i+m) - x
        w    = c(i+1) - d(i)
        den  = ho - hp
        if (den .eq. 0.0) stop ' 2 xa entries are the same in polint'
        den  = w/den
        d(i) = hp * den
        c(i) = ho * den
       enddo

!..after each column is completed, decide which correction c or d, to add
!..to the accumulating value of y, that is, which path to take in the table
!..by forking up or down. ns is updated as we go to keep track of where we
!..are. the last dy added is the error indicator.
       if (2*ns .lt. n-m) then
        dy = c(ns+1)
       else
        dy = d(ns)
        ns = ns - 1
       end if
       y = y + dy
      enddo
      return
      end


