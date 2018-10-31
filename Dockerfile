FROM ubuntu:xenial
MAINTAINER <alik@robarts.ca>

RUN mkdir -p /gradcorrect
COPY . /gradcorrect

ENV DEBIAN_FRONTENDnoninteractive
RUN bash /gradcorrect/deps/00.install_basics_sudo.sh
RUN bash /gradcorrect/deps/03.install_anaconda2_nipype_dcmstack_by_binary.sh /opt
RUN bash /gradcorrect/deps/10.install_afni_fsl_sudo.sh
RUN bash /gradcorrect/deps/12.install_c3d_by_binary.sh /opt
RUN bash /gradcorrect/deps/16.install_ants_by_binary.sh /opt
RUN bash /gradcorrect/deps/25.install_niftyreg_by_source.sh /opt
RUN bash /gradcorrect/deps/28.install_gradunwarp_by_source.sh /opt


#anaconda2
ENV PATH /opt/anaconda2/bin/:$PATH

#fsl
ENV FSLDIR /usr/share/fsl/5.0
ENV POSSUMDIR $FSLDIR
ENV PATH /usr/lib/fsl/5.0:$PATH
ENV FSLOUTPUTTYPE NIFTI_GZ
ENV FSLMULTIFILEQUIT TRUE
ENV FSLTCLSH /usr/bin/tclsh
ENV FSLWISH /usr/bin/wish
ENV FSLBROWSER /etc/alternatives/x-www-browser
ENV LD_LIBRARY_PATH /usr/lib/fsl/5.0:${LD_LIBRARY_PATH}

#c3d
ENV PATH /opt/c3d/bin:$PATH

#ants
ENV PATH /opt/ants:$PATH
ENV ANTSPATH /opt/ants


#niftyreg
ENV LD_LIBRARY_PATH /opt/niftyreg-1.3.9/lib:$LD_LIBRARY_PATH 
ENV PATH /opt/niftyreg-1.3.9/bin:$PATH

#this app:
ENV PATH /gradcorrect:$PATH

ENTRYPOINT ["/gradcorrect/run.sh"]
