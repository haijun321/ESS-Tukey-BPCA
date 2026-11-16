function h=NB_RA_CONFIG_HASH(C)
    s=struct('grid',C.raLambdaGrid,'maxOuter',C.raMaxOuter,'tolerance',C.raTolerance, ...
        'geometry',C.syntheticDimensions,'protocol','training_only_activation_check_v2');
    h=P0_IO('hashtext',jsonencode(s));
end
